# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      # Detects which operations should be broadcast over arrays
      # DEPENDENCIES: :inputs, :declarations
      # PRODUCES: :broadcasts
      class BroadcastDetector < PassBase
        def run(errors)
          input_meta = get_state(:inputs) || {}
          definitions = get_state(:declarations) || {}
          
          # Find array fields with their element types
          array_fields = find_array_fields(input_meta)
          
          # Build compiler metadata
          compiler_metadata = {
            array_fields: array_fields,
            vectorized_operations: {},
            reduction_operations: {}
          }
          
          # Track which values are vectorized for type inference
          vectorized_values = {}
          
          # Analyze traits first, then values (to handle dependencies)
          traits = definitions.select { |name, decl| decl.is_a?(Kumi::Syntax::TraitDeclaration) }
          values = definitions.select { |name, decl| decl.is_a?(Kumi::Syntax::ValueDeclaration) }
          
          (traits.to_a + values.to_a).each do |name, decl|
            result = analyze_value_vectorization(name, decl.expression, array_fields, vectorized_values, errors)
            
            
            case result[:type]
            when :vectorized
              compiler_metadata[:vectorized_operations][name] = result[:info]
              # Store array source information for dimension checking
              array_source = extract_array_source(result[:info], array_fields)
              vectorized_values[name] = { vectorized: true, array_source: array_source }
            when :reduction
              compiler_metadata[:reduction_operations][name] = result[:info]
              # Reduction produces scalar, not vectorized
              vectorized_values[name] = { vectorized: false }
            end
          end
          
          state.with(:broadcasts, compiler_metadata.freeze)
        end

        private

        def find_array_fields(input_meta)
          result = {}
          input_meta.each do |name, meta|
            if meta[:type] == :array && meta[:children]
              result[name] = {
                element_fields: meta[:children].keys,
                element_types: meta[:children].transform_values { |v| v[:type] || :any }
              }
            end
          end
          result
        end

        def analyze_value_vectorization(name, expr, array_fields, vectorized_values, errors)
          case expr
          when Kumi::Syntax::InputElementReference
            if array_fields.key?(expr.path.first)
              { type: :vectorized, info: { source: :array_field_access, path: expr.path } }
            else
              { type: :scalar }
            end
            
          when Kumi::Syntax::DeclarationReference
            # Check if this references a vectorized value
            vector_info = vectorized_values[expr.name]
            if vector_info && vector_info[:vectorized]
              { type: :vectorized, info: { source: :vectorized_declaration, name: expr.name } }
            else
              { type: :scalar }
            end
            
          when Kumi::Syntax::CallExpression
            analyze_call_vectorization(name, expr, array_fields, vectorized_values, errors)
            
          when Kumi::Syntax::CascadeExpression
            analyze_cascade_vectorization(name, expr, array_fields, vectorized_values, errors)
            
          else
            { type: :scalar }
          end
        end

        def analyze_call_vectorization(name, expr, array_fields, vectorized_values, errors)
          # Check if this is a reduction function using function registry metadata
          if FunctionRegistry.reducer?(expr.fn_name)
            # Only treat as reduction if the argument is actually vectorized
            arg_info = analyze_argument_vectorization(expr.args.first, array_fields, vectorized_values)
            if arg_info[:vectorized]
              { type: :reduction, info: { function: expr.fn_name, source: arg_info[:source] } }
            else
              # Not a vectorized reduction - just a regular function call
              { type: :scalar }
            end
            
          else
            # Special case: all?, any?, none? functions with vectorized trait arguments should be treated as vectorized
            # for cascade condition purposes (they get transformed during compilation)
            if [:all?, :any?, :none?].include?(expr.fn_name) && expr.args.length == 1
              arg = expr.args.first
              if arg.is_a?(Kumi::Syntax::ArrayExpression) && arg.elements.length == 1
                trait_ref = arg.elements.first
                if trait_ref.is_a?(Kumi::Syntax::DeclarationReference) && vectorized_values[trait_ref.name]&.[](:vectorized)
                  return { type: :vectorized, info: { source: :cascade_condition_with_vectorized_trait, trait: trait_ref.name } }
                end
              end
            end
            
            # ANY function with vectorized arguments becomes vectorized (with broadcasting)
            arg_infos = expr.args.map { |arg| analyze_argument_vectorization(arg, array_fields, vectorized_values) }
            
            if arg_infos.any? { |info| info[:vectorized] }
              # Check for dimension mismatches when multiple arguments are vectorized
              vectorized_sources = arg_infos.select { |info| info[:vectorized] }.map { |info| info[:array_source] }.compact.uniq
              
              if vectorized_sources.length > 1
                # Multiple different array sources - this is a dimension mismatch
                # Generate enhanced error message with type information
                enhanced_message = build_dimension_mismatch_error(expr, arg_infos, array_fields, vectorized_sources)
                
                report_error(errors, enhanced_message, location: expr.loc, type: :semantic)
                return { type: :scalar }  # Treat as scalar to prevent further errors
              end
              
              # This is a vectorized operation - ANY function supports broadcasting
              { type: :vectorized, info: { 
                operation: expr.fn_name, 
                vectorized_args: arg_infos.map.with_index { |info, i| [i, info[:vectorized]] }.to_h 
              }}
            else
              { type: :scalar }
            end
          end
        end

        def analyze_argument_vectorization(arg, array_fields, vectorized_values)
          case arg
          when Kumi::Syntax::InputElementReference
            if array_fields.key?(arg.path.first)
              { vectorized: true, source: :array_field, array_source: arg.path.first }
            else
              { vectorized: false }
            end
            
          when Kumi::Syntax::DeclarationReference
            # Check if this references a vectorized value
            vector_info = vectorized_values[arg.name]
            if vector_info && vector_info[:vectorized]
              array_source = vector_info[:array_source]
              { vectorized: true, source: :vectorized_value, array_source: array_source }
            else
              { vectorized: false }
            end
            
          when Kumi::Syntax::CallExpression
            # Recursively check
            result = analyze_value_vectorization(nil, arg, array_fields, vectorized_values, [])
            { vectorized: result[:type] == :vectorized, source: :expression }
            
          else
            { vectorized: false }
          end
        end

        def extract_array_source(info, array_fields)
          case info[:source]
          when :array_field_access
            info[:path]&.first
          when :cascade_condition_with_vectorized_trait
            # For cascades, we'd need to trace back to the original source
            nil  # TODO: Could be enhanced to trace through trait dependencies
          else
            nil
          end
        end

        def analyze_cascade_vectorization(name, expr, array_fields, vectorized_values, errors)
          # A cascade is vectorized if:
          # 1. Any of its result expressions are vectorized, OR
          # 2. Any of its conditions reference vectorized values (traits or arrays)
          vectorized_results = []
          vectorized_conditions = []
          
          expr.cases.each do |case_expr|
            # Check if result is vectorized
            result_info = analyze_value_vectorization(nil, case_expr.result, array_fields, vectorized_values, errors)
            vectorized_results << (result_info[:type] == :vectorized)
            
            # Check if condition is vectorized
            condition_info = analyze_value_vectorization(nil, case_expr.condition, array_fields, vectorized_values, errors)
            vectorized_conditions << (condition_info[:type] == :vectorized)
            
          end
          
          if vectorized_results.any? || vectorized_conditions.any?
            { type: :vectorized, info: { source: :cascade_with_vectorized_conditions_or_results } }
          else
            { type: :scalar }
          end
        end

        def build_dimension_mismatch_error(_expr, arg_infos, array_fields, vectorized_sources)
          # Build detailed error message with type information
          summary = "Cannot broadcast operation across arrays from different sources: #{vectorized_sources.join(', ')}. "
          
          problem_desc = "Problem: Multiple operands are arrays from different sources:\n"
          
          vectorized_args = arg_infos.select { |info| info[:vectorized] }
          vectorized_args.each_with_index do |arg_info, index|
            array_source = arg_info[:array_source]
            next unless array_source && array_fields[array_source]

            # Determine the type based on array field metadata
            type_desc = determine_array_type(array_source, array_fields)
            problem_desc += "  - Operand #{index + 1} resolves to #{type_desc} from array '#{array_source}'\n"
          end
          
          explanation = "Direct operations on arrays from different sources is ambiguous and not supported. " \
                        "Vectorized operations can only work on fields from the same array input."
          
          "#{summary}#{problem_desc}#{explanation}"
        end

        def determine_array_type(array_source, array_fields)
          field_info = array_fields[array_source]
          return "array(any)" unless field_info[:element_types]

          # For nested arrays (like items.name where items is an array), this represents array(element_type)
          element_types = field_info[:element_types].values.uniq
          if element_types.length == 1
            "array(#{element_types.first})"
          else
            "array(mixed)"
          end
        end

      end
    end
  end
end