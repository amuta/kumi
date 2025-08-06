# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Clean BroadcastDetector implementation based on clear strategy taxonomy
        class BroadcastDetector < PassBase
          def initialize(schema, state)
            @schema = schema
            @state = state
            @metadata = {}
          end

          def run(errors)
            (@schema.attributes + @schema.traits).each do |declaration|
              @metadata[declaration.name] = analyze_declaration(declaration)
            rescue StandardError => e
              add_error(errors, declaration.loc, "BroadcastDetector error: #{e.message}")
            end

            @state.with(:detector_metadata, @metadata.freeze)
          end

          private

          def analyze_declaration(declaration)
            expr = declaration.expression

            case expr
            when Kumi::Syntax::CallExpression
              analyze_call_expression(expr)
            when Kumi::Syntax::CascadeExpression
              analyze_cascade_expression(expr)
            when Kumi::Syntax::InputElementReference, Kumi::Syntax::InputReference
              analyze_array_reference(expr)
            else
              { operation_type: :scalar }
            end
          end

          def analyze_call_expression(expr)
            # Check if this is a reduction function
            return analyze_reduction(expr) if reduction_function?(expr.fn_name)

            # Analyze operands
            operands = expr.args.map { |arg| analyze_operand(arg) }

            # Determine operation type and strategy
            if all_scalar?(operands)
              { operation_type: :scalar }
            elsif operands.size == 1 && operands[0][:type] == :array
              # Single array operand - this is likely an array reference being used in a function
              # Let the reduction detection handle it, or treat as array_reference
              { operation_type: :array_reference, array_source: extract_array_source(operands[0]) }
            else
              analyze_vectorized_operation(expr, operands)
            end
          end

          def analyze_vectorized_operation(expr, operands)
            # Find the array operand(s) and determine access mode
            array_operands = operands.select { |op| op[:type] == :array }
            scalar_operands = operands.select { |op| op[:type] == :scalar }

            return { operation_type: :scalar } if array_operands.empty?

            # Determine access mode from first array operand
            puts "Array operands: #{array_operands}"
            access_mode = determine_access_mode(array_operands.first)

            # Determine dimension relationship
            dimension_mode = determine_dimension_mode(array_operands)

            # Select strategy based on our taxonomy
            strategy = determine_strategy(array_operands, scalar_operands, dimension_mode, access_mode)

            {
              operation_type: :vectorized,
              strategy: strategy,
              access_mode: access_mode,
              dimension_mode: dimension_mode,
              operands: operands,
              array_source: extract_array_source(array_operands.first),
              registry_call_info: build_registry_call_info(strategy, operands, access_mode)
            }
          end

          def determine_strategy(array_operands, scalar_operands, dimension_mode, access_mode)
            case [array_operands.size, scalar_operands.size, dimension_mode, access_mode]
            when [1, 1, :same_level, :object]
              :array_scalar_object
            when [2, 0, :same_level, :object]
              :element_wise_object
            when [2, 0, :parent_child, :object]
              :parent_child_object
            when [1, 1, :same_level, :vector]
              :array_scalar_vector
            when [2, 0, :same_level, :vector]
              :element_wise_vector
            when [2, 0, :parent_child, :vector]
              :parent_child_vector
            else
              raise "Unknown strategy for arrays=#{array_operands.size}, scalars=#{scalar_operands.size}, mode=#{dimension_mode}, access=#{access_mode}"
            end
          end

          def determine_access_mode(array_operand)
            source = array_operand[:source]
            
            # Handle declaration references
            return :object if source[:kind] == :declaration
            
            path = source[:path]
            return :object unless path # Fallback if no path

            # Use the input metadata that was already collected by InputCollector
            input_metadata = @state[:inputs] || {}

            # Look up the access mode from the root array in the path
            root_field = path.first
            root_metadata = input_metadata[root_field]

            # Return the access mode directly from parser metadata
            root_metadata&.[](:access_mode) || :object
          end

          def determine_dimension_mode(array_operands)
            return :same_level if array_operands.size == 1

            # Compare dimensions of array operands
            depths = array_operands.map { |op| op[:source][:depth] || 1 }

            if depths.uniq.size == 1
              :same_level
            else
              :parent_child
            end
          end

          def analyze_operand(operand)
            case operand
            when Kumi::Syntax::InputElementReference
              # Use input metadata to determine actual type
              return { type: :scalar, source: { kind: :unknown } } if operand.path.nil? || operand.path.empty?

              root_field = operand.path.first
              input_metadata = @state[:inputs] || {}
              root_meta = input_metadata[root_field]

              # Determine if this reference represents an array or scalar based on metadata
              operand_type = determine_operand_type_from_metadata(operand.path, input_metadata)

              {
                type: operand_type,
                source: {
                  kind: :input_element,
                  path: operand.path,
                  depth: operand.path.size - 1,
                  root: operand.path.first
                }
              }
            when Kumi::Syntax::InputReference
              # Use input metadata to determine actual type
              input_metadata = @state[:inputs] || {}
              field_meta = input_metadata[operand.name]

              # A field reference could be array or scalar depending on its declared type
              operand_type = field_meta&.[](:type) == :array ? :array : :scalar

              {
                type: operand_type,
                source: {
                  kind: :input_field,
                  name: operand.name
                }
              }
            when Kumi::Syntax::Literal
              {
                type: :scalar,
                source: {
                  kind: :literal,
                  value: operand.value
                }
              }
            when Kumi::Syntax::DeclarationReference
              # Look up the declaration's metadata to determine if it's an array
              decl_metadata = @metadata[operand.name]
              operand_type = if decl_metadata && 
                               (decl_metadata[:operation_type] == :vectorized || 
                                decl_metadata[:operation_type] == :array_reference)
                               :array
                             else
                               :scalar
                             end
              
              {
                type: operand_type,
                source: {
                  kind: :declaration,
                  name: operand.name
                }
              }
            when Kumi::Syntax::CallExpression
              # Nested function call - analyze it recursively
              nested_metadata = analyze_call_expression(operand)

              # Determine the type based on the nested operation
              operand_type = case nested_metadata[:operation_type]
                             when :reduction, :array_reference
                               # Reductions and array references produce arrays (or scalars for some reductions)
                               # For now, assume they produce the type that would be consumed by the parent function
                               :array # Most functions that take nested calls expect arrays
                             when :vectorized
                               :array
                             else
                               :scalar
                             end

              {
                type: operand_type,
                source: {
                  kind: :nested_call,
                  metadata: nested_metadata
                }
              }
            else
              {
                type: :unknown,
                source: { kind: :unknown }
              }
            end
          end

          def extract_array_source(array_operand)
            source = array_operand[:source]
            
            case source[:kind]
            when :declaration
              # For declaration references, we don't have path/root/depth
              {
                declaration: source[:name],
                access_mode: :object # Declaration references typically produce object-mode arrays
              }
            else
              {
                root: source[:root],
                path: source[:path],
                depth: source[:depth],
                access_mode: determine_access_mode(array_operand)
              }
            end
          end

          def build_registry_call_info(strategy, operands, access_mode)
            {
              function_name: strategy,
              operand_extraction: operands.map { |op| build_extraction_info(op, access_mode) }
            }
          end

          def build_extraction_info(operand, access_mode)
            case operand[:source][:kind]
            when :input_element
              {
                type: :array_field,
                path: operand[:source][:path],
                field: operand[:source][:path].last,
                access_mode: access_mode
              }
            when :literal
              {
                type: :literal_value,
                value: operand[:source][:value]
              }
            else
              {
                type: :unknown,
                source: operand[:source]
              }
            end
          end

          def analyze_reduction(expr)
            input_arg = expr.args.first
            input_operand = analyze_operand(input_arg)

            {
              operation_type: :reduction,
              function: expr.fn_name,
              input_source: input_operand,
              requires_flattening: false # TODO: Determine when flattening is needed
            }
          end

          def analyze_cascade_expression(expr)
            # For now, mark as scalar - cascade analysis is complex
            # TODO: Implement proper cascade analysis
            { operation_type: :scalar }
          end

          def analyze_array_reference(expr)
            {
              operation_type: :array_reference,
              array_source: {
                root: expr.respond_to?(:path) ? expr.path.first : expr.name,
                path: expr.respond_to?(:path) ? expr.path : [expr.name],
                access_mode: :object # TODO: Determine actual access mode
              }
            }
          end

          # Helper methods
          def reduction_function?(fn_name)
            # Check for both reducer functions AND structure functions
            # Both need special handling as they transform arrays
            Kumi::Registry.reducer?(fn_name) || Kumi::Registry.structure_function?(fn_name)
          end

          def all_scalar?(operands)
            operands.all? { |op| op[:type] == :scalar }
          end

          def determine_operand_type_from_metadata(path, input_metadata)
            # Navigate through the path using metadata to determine final type
            return :scalar if path.nil? || path.empty?

            current_meta = input_metadata[path.first]
            return :scalar unless current_meta

            # If it's just a single field reference (path length 1), use its type directly
            if path.length == 1
              return current_meta[:type] == :array ? :array : :scalar
            end

            # For nested paths like [:line_items, :price] or [:matrix, :cell]
            # If the root is an array, then accessing fields within it is an array operation
            if current_meta[:type] == :array
              # Any field access within an array is an array operation
              # The access_mode determines HOW we traverse, not WHETHER it's an array operation
              return :array
            end

            # If root is not an array, continue traversing
            # This handles nested object structures
            remaining_path = path[1..-1]
            remaining_path.each do |segment|
              break unless current_meta[:children] && current_meta[:children][segment]

              current_meta = current_meta[:children][segment]
              return :array if current_meta[:type] == :array
            end

            # Default fallback
            :scalar
          end
        end
      end
    end
  end
end
