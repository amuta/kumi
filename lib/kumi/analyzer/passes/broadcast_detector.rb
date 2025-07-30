# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      # Detects which operations should be broadcast over arrays
      # DEPENDENCIES: :input_meta, :definitions
      # PRODUCES: :broadcast_metadata
      class BroadcastDetector < PassBase
        def run(errors)
          input_meta = get_state(:input_meta) || {}
          definitions = get_state(:definitions) || {}
          
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
              vectorized_values[name] = true
            when :reduction
              compiler_metadata[:reduction_operations][name] = result[:info]
              # Reduction produces scalar, not vectorized
              vectorized_values[name] = false
            end
          end
          
          state.with(:broadcast_metadata, compiler_metadata.freeze)
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
            if vectorized_values[expr.name]
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
                if trait_ref.is_a?(Kumi::Syntax::DeclarationReference) && vectorized_values[trait_ref.name]
                  return { type: :vectorized, info: { source: :cascade_condition_with_vectorized_trait, trait: trait_ref.name } }
                end
              end
            end
            
            # ANY function with vectorized arguments becomes vectorized (with broadcasting)
            arg_infos = expr.args.map { |arg| analyze_argument_vectorization(arg, array_fields, vectorized_values) }
            
            if arg_infos.any? { |info| info[:vectorized] }
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
              { vectorized: true, source: :array_field }
            else
              { vectorized: false }
            end
            
          when Kumi::Syntax::DeclarationReference
            # Check if this references a vectorized value
            if vectorized_values[arg.name]
              { vectorized: true, source: :vectorized_value }
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

      end
    end
  end
end