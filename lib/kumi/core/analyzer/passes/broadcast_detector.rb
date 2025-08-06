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

            # @state[:evaluation_order]

            # @state
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
            # binding.pry
            # Analyze operands
            operands = expr.args.map { |arg| analyze_operand(arg) }

            # Determine operation type and strategy
            if all_scalar?(operands)
              { operation_type: :scalar }
            else
              analyze_element_wise_operation(expr, operands)
            end
          end

          def analyze_element_wise_operation(expr, operands)
            # Find the source operand(s) and determine access mode
            source_operands = operands.select { |op| op[:type] == :source }
            scalar_operands = operands.select { |op| op[:type] == :scalar }

            return { operation_type: :scalar } if source_operands.empty?

            # Determine access mode from first source operand
            access_mode = determine_access_mode(source_operands.first)

            # Determine dimension relationship
            dimension_mode = determine_dimension_mode(source_operands)

            # Calculate depth for element-wise operations
            primary_depth = source_operands.first&.dig(:source, :depth) || 1

            {
              operation_type: :element_wise,
              access_mode: access_mode,
              dimension_mode: dimension_mode,
              depth: primary_depth,
              operands: operands,
              source_info: extract_source_info(source_operands.first)
            }
          end

          def determine_strategy(array_operands, scalar_operands, dimension_mode, access_mode)
            case [array_operands.size, scalar_operands.size, dimension_mode, access_mode]
            when [1, 0, :same_level, :object]
              :array_function_object
            when [1, 0, :same_level, :vector]
              :array_function_vector
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

          def determine_dimension_mode(source_operands)
            return :same_level if source_operands.size == 1

            # Compare dimensions of source operands
            depths = source_operands.map { |op| op[:source][:depth] || 1 }

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

              # A field reference could be source or scalar depending on its declared type
              operand_type = field_meta&.[](:type) == :array ? :source : :scalar

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
                                %i[element_wise array_reference].include?(decl_metadata[:operation_type])
                               :source
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
              # Recursive analysis of inline call expression
              nested_metadata = analyze_call_expression(operand)

              # The recursive analysis tells us exactly what this produces
              operand_type = case nested_metadata[:operation_type]
                             when :element_wise, :array_reference
                               :source
                             when :scalar
                               :scalar
                             when :reduction
                               # TODO: Some reductions produce scalars, others produce sources
                               # We should use the function signature to determine this
                               :source
                             else
                               :scalar
                             end

              {
                type: operand_type,
                source: {
                  kind: :computed_result,
                  operation_metadata: nested_metadata
                }
              }
            else
              {
                type: :unknown,
                source: { kind: :unknown }
              }
            end
          end

          def extract_source_info(source_operand)
            puts "DEBUG: Extracting source info from operand: #{source_operand.inspect}" if ENV["DEBUG_COMPILER"]
            source = source_operand[:source]

            # binding.pry
            case source[:kind]
            when :declaration
              # For declaration references, we don't have path/root/depth
              {
                declaration: source[:name],
                access_mode: :object # Declaration references typically produce object-mode sources
              }
            else
              {
                root: source[:root],
                path: source[:path],
                depth: source[:depth],
                access_mode: determine_access_mode(source_operand)
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
              requires_flattening: flattening_required?(expr.fn_name, input_operand)
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
              source_info: {
                root: expr.respond_to?(:path) ? expr.path.first : expr.name,
                path: expr.respond_to?(:path) ? expr.path : [expr.name],
                access_mode: :object # TODO: Determine actual access mode
              }
            }
          end

          # Helper methods
          def reduction_function?(fn_name)
            # Check if this is a reducer or structure function
            if fn_name.nil? || fn_name.to_s.empty?
              raise "BroadcastDetector: Empty function name encountered! Call analyze_call_expression with #{fn_name.inspect}"
            end

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
              return current_meta[:type] == :array ? :source : :scalar
            end

            # For nested paths like [:line_items, :price] or [:matrix, :cell]
            # If the root is an array, then accessing fields within it is a source operation
            if current_meta[:type] == :array
              # Any field access within an array is a source operation
              # The access_mode determines HOW we traverse, not WHETHER it's a source operation
              return :source
            end

            # If root is not an array, continue traversing
            # This handles nested object structures
            remaining_path = path[1..-1]
            remaining_path.each do |segment|
              break unless current_meta[:children] && current_meta[:children][segment]

              current_meta = current_meta[:children][segment]
              return :source if current_meta[:type] == :array
            end

            # Default fallback
            :scalar
          end

          def flattening_required?(fn_name, input_operand)
            # Case 1: Explicitly check for a flattener function, e.g., fn(:size, fn(:flatten, ...))
            if input_operand.dig(:source, :kind) == :nested_call
              nested_fn_name = input_operand.dig(:source, :metadata, :function)
              nested_meta = Kumi::Registry.signature(nested_fn_name)
              return true if nested_meta&.[](:capability) == :flattener
            end

            # Case 2: Implicitly flatten for aggregate reducers on element-mode arrays
            outer_meta = Kumi::Registry.signature(fn_name)
            return false unless outer_meta&.[](:type) == :aggregate_reducer

            is_element_mode = determine_access_mode(input_operand) != :object
            is_nested_path = input_operand.dig(:source, :kind) == :input_element

            is_element_mode && is_nested_path
          end
        end
      end
    end
  end
end
