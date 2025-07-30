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
          
          # Analyze each declaration for vectorization patterns  
          definitions.each do |name, decl|
            next unless decl.is_a?(Kumi::Syntax::ValueDeclaration) || decl.is_a?(Kumi::Syntax::TraitDeclaration)
            
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
            
          when Kumi::Syntax::CallExpression
            analyze_call_vectorization(name, expr, array_fields, vectorized_values, errors)
            
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

      end
    end
  end
end