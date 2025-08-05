# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Clean, simple broadcast detector that provides complete compilation metadata
        # DEPENDENCIES: :inputs, :declarations
        # PRODUCES: :broadcasts, :detector_metadata
        class NewBroadcastDetector < PassBase
          def initialize(schema, state)
            super
            @metadata = {}
            @input_meta = get_state(:inputs) || {}
            @declarations = get_state(:declarations) || {}
            @nested_paths = build_nested_paths_metadata(@input_meta)
            @array_fields = find_array_fields(@input_meta)
          end

          def run(errors)
            # Use dependency-aware analysis to handle circular references
            # Get topological order from previous analyzer pass
            topo_order = get_state(:evaluation_order) || @declarations.keys

            # Analyze in dependency order with memoization to handle cycles
            @analyzed = {}
            topo_order.each do |name|
              next unless @declarations[name]

              analyze_declaration_memoized(name, @declarations[name], errors)
            end

            # Handle any remaining declarations not in topo order
            @declarations.each do |name, declaration|
              next if @analyzed.key?(name)

              analyze_declaration_memoized(name, declaration, errors)
            end

            # Build compiler-compatible metadata structure
            compiler_metadata = build_compiler_metadata(@metadata)
            
            # Store results in the format expected by the compiler
            state.with(:broadcasts, compiler_metadata.freeze)
                 .with(:detector_metadata, @metadata.freeze)
          end

          private

          def analyze_declaration_memoized(name, declaration, errors)
            return @metadata[name] if @analyzed.key?(name)

            # Mark as being analyzed to prevent infinite recursion
            @analyzed[name] = true

            # Analyze the declaration
            @metadata[name] = analyze_declaration(declaration, errors)

            @metadata[name]
          end

          def analyze_declaration(declaration, errors)
            analyze_expression(declaration.expression, errors)
          end

          def analyze_expression(expr, errors)
            case expr
            when Kumi::Syntax::CallExpression
              analyze_call_expression(expr, errors)
            when Kumi::Syntax::CascadeExpression
              analyze_cascade_expression(expr, errors)
            when Kumi::Syntax::InputElementReference
              analyze_input_element_reference(expr)
            when Kumi::Syntax::DeclarationReference
              analyze_declaration_reference(expr)
            when Kumi::Syntax::Literal
              { operation_type: :scalar, compilation: scalar_compilation_hints }
            else
              { operation_type: :scalar, compilation: scalar_compilation_hints }
            end
          end

          def analyze_call_expression(expr, errors)
            # Check if this is a reduction function
            return analyze_reduction(expr, errors) if reduction_function?(expr.fn_name)

            # Analyze arguments
            arg_analyses = expr.args.map { |arg| analyze_expression(arg, errors) }

            # Build detailed operand information
            operands = expr.args.map.with_index do |arg, idx|
              analysis = arg_analyses[idx]
              {
                index: idx,
                type: vectorized?(analysis) ? :array : :scalar,
                source: build_source_info(arg)
              }
            end

            vectorized_count = operands.count { |op| op[:type] == :array }

            if vectorized_count == 0
              { operation_type: :scalar, compilation: scalar_compilation_hints }
            else
              # Extract all dimensions from array operands
              dimensions_list = operands.select { |op| op[:type] == :array }.map do |op|
                source = op[:source]
                if source[:kind] == :input_element
                  source[:dimensions] || []
                else
                  []
                end
              end

              # Determine strategy based on dimensions and operand types
              strategy = if vectorized_count == 1
                           vectorized_idx = operands.find_index { |op| op[:type] == :array }
                           vectorized_idx == 0 ? :broadcast_scalar : :broadcast_scalar_first
                         elsif dimensions_list.uniq.length > 1
                           # Multiple array operands - check if they have different dimensions (hierarchical)
                           sorted_dims = dimensions_list.sort_by(&:length)
                           longer_dims = sorted_dims.last
                           longer_idx = dimensions_list.find_index(longer_dims)
                           longer_idx == 0 ? :broadcast_scalar : :broadcast_scalar_first
                         # Different dimensions - this could be hierarchical broadcasting
                         # Use broadcast_scalar strategy with the deeper array as primary
                         else
                           # Same dimensions - zip map
                           :zip_map
                         end

              # Check dimension compatibility
              dimension_info = check_dimension_compatibility(dimensions_list)

              # Find primary array source
              first_array_analysis = arg_analyses.find { |a| vectorized?(a) }
              array_source = first_array_analysis[:array_source] || extract_array_source(first_array_analysis)

              # Build compilation hints
              compilation_hints = {
                evaluation_mode: :broadcast,
                expects_array_input: true,
                produces_array_output: true,
                requires_flattening: false,
                requires_dimension_check: dimension_info[:mode] != :same_level,
                requires_hierarchical_logic: dimension_info[:mode] == :hierarchical
              }

              {
                operation_type: :vectorized,
                array_source: array_source,
                vectorization: {
                  strategy: strategy,
                  operands: operands,
                  dimension_info: dimension_info
                },
                compilation: compilation_hints
              }
            end
          end

          def analyze_cascade_expression(expr, errors)
            # Separate base case from conditional cases
            conditional_cases = expr.cases.reject { |c| base_case?(c) }
            base_case = expr.cases.find { |c| base_case?(c) }

            # Analyze conditions and results
            condition_analyses = conditional_cases.map { |c| analyze_expression(c.condition, errors) }
            result_analyses = conditional_cases.map { |c| analyze_expression(c.result, errors) }
            base_analysis = base_case ? analyze_expression(base_case.result, errors) : nil

            # Check if any conditions or results are vectorized
            is_vectorized = condition_analyses.any? { |a| vectorized?(a) } ||
                            result_analyses.any? { |a| vectorized?(a) } ||
                            (base_analysis && vectorized?(base_analysis))

            if is_vectorized
              # Find array source and collect all dimensions
              array_source = nil
              all_dimensions = []

              # Collect dimensions from all vectorized elements
              all_analyses = [condition_analyses, result_analyses, [base_analysis]].flatten.compact
              all_analyses.each do |analysis|
                next unless vectorized?(analysis)

                array_source ||= extract_array_source(analysis)

                # For cascades, we need to extract ALL dimensions, including hierarchical ones
                if analysis[:vectorization] && analysis[:vectorization][:dimension_info]
                  # If the referenced analysis has hierarchical info, use all its dimensions
                  nested_dims = analysis[:vectorization][:dimension_info][:all_dimensions]
                  if nested_dims && nested_dims.length > 1
                    all_dimensions.concat(nested_dims)
                  else
                    dims = extract_dimensions(analysis)
                    all_dimensions << dims unless dims.empty?
                  end
                else
                  dims = extract_dimensions(analysis)
                  all_dimensions << dims unless dims.empty?
                end
              end

              # Check dimension compatibility - this is the key decision point
              dimension_info = check_dimension_compatibility(all_dimensions)

              # Determine cascade processing mode based on array depth
              processing_mode = case array_source[:depth]
                                when 0, 1 then :simple_array
                                when 2, 3, 4 then :nested_array
                                else :deep_nested
                                end

              # Build detailed condition information
              conditions = conditional_cases.map.with_index do |case_expr, idx|
                analysis = condition_analyses[idx]
                condition_info = {
                  index: idx,
                  type: vectorized?(analysis) ? :array : :scalar,
                  source: build_source_info(case_expr.condition),
                  is_composite: false,
                  composite_parts: []
                }

                # Check for cascade_and
                if case_expr.condition.is_a?(Kumi::Syntax::CallExpression) &&
                   case_expr.condition.fn_name == :cascade_and
                  condition_info[:is_composite] = true
                  condition_info[:composite_parts] = case_expr.condition.args.map do |arg|
                    build_source_info(arg)
                  end
                end

                condition_info
              end

              # Build detailed result information
              results = result_analyses.map.with_index do |analysis, idx|
                {
                  index: idx,
                  type: vectorized?(analysis) ? :array : :scalar,
                  source: build_source_info(conditional_cases[idx].result)
                }
              end

              # Add base case if present
              if base_case
                results << {
                  index: results.length,
                  type: vectorized?(base_analysis) ? :array : :scalar,
                  source: build_source_info(base_case.result)
                }
              end

              # Build compilation hints
              compilation_hints = {
                evaluation_mode: :cascade,
                expects_array_input: true,
                produces_array_output: true,
                requires_flattening: false,
                requires_dimension_check: dimension_info[:mode] != :same_level,
                requires_hierarchical_logic: dimension_info[:mode] == :hierarchical
              }

              {
                operation_type: :vectorized,
                array_source: array_source,
                cascade: {
                  is_vectorized: true,
                  processing: {
                    mode: processing_mode,
                    depth: array_source[:depth],
                    strategy: dimension_info[:mode] == :hierarchical ? :hierarchical_broadcast : :element_wise
                  },
                  conditions: conditions,
                  results: results
                },
                vectorization: {
                  dimension_info: dimension_info
                },
                compilation: compilation_hints
              }
            else
              { operation_type: :scalar, compilation: scalar_compilation_hints }
            end
          end

          def analyze_reduction(expr, errors)
            # Assume first argument is the array to reduce
            arg_analysis = analyze_expression(expr.args.first, errors)

            if vectorized?(arg_analysis)
              array_source = arg_analysis[:array_source] || extract_array_source(arg_analysis)
              input_source = build_source_info(expr.args.first)

              # Determine flattening requirements
              requires_flattening = array_source[:depth] > 1
              flatten_depth = requires_flattening ? :all : 1

              {
                operation_type: :reduction,
                array_source: array_source,
                reduction: {
                  function: expr.fn_name,
                  input: {
                    source: input_source,
                    requires_flattening: requires_flattening,
                    flatten_depth: flatten_depth
                  }
                },
                compilation: {
                  evaluation_mode: :reduce,
                  expects_array_input: true,
                  produces_array_output: false,
                  requires_flattening: requires_flattening,
                  requires_dimension_check: false,
                  requires_hierarchical_logic: false
                }
              }
            else
              { operation_type: :scalar, compilation: scalar_compilation_hints }
            end
          end

          def analyze_input_element_reference(expr)
            # Check if this references an array field
            if array_field?(expr.path)
              path_info = @nested_paths[expr.path] || build_path_info(expr.path)
              {
                operation_type: :array_reference,
                array_source: {
                  root: expr.path.first,
                  path: expr.path,
                  dimensions: expr.path[0..-2], # All but the last element
                  depth: path_info[:depth] || 1,
                  access_mode: path_info[:access_mode] || :object
                }
              }
            else
              { operation_type: :scalar, compilation: scalar_compilation_hints }
            end
          end

          def analyze_declaration_reference(expr)
            # Look up the referenced declaration
            referenced_decl = @declarations[expr.name]
            if referenced_decl
              # If we've already analyzed it, use that
              if @metadata[expr.name]
                # Return the full metadata for references to preserve all information
                @metadata[expr.name]
              else
                # Analyze it now (recursive) - this shouldn't happen with proper ordering
                analyze_declaration(referenced_decl, [])
              end
            else
              { operation_type: :scalar, compilation: scalar_compilation_hints }
            end
          end

          # Helper methods

          def vectorized?(analysis)
            %i[array_reference vectorized].include?(analysis[:operation_type])
          end

          def extract_array_source(analysis)
            case analysis[:operation_type]
            when :array_reference
              analysis[:array_source]
            when :vectorized
              analysis[:array_source] ||
                analysis.dig(:vectorization, :array_length_source) ||
                analysis.dig(:cascade, :array_length_source)
            else
              # Build a default array source
              {
                root: :unknown,
                path: [],
                dimensions: [],
                depth: 1,
                access_mode: :object
              }
            end
          end

          def array_field?(path)
            return false if path.empty?

            # Check if we have this path in nested_paths (which includes all array-accessible paths)
            return true if @nested_paths.key?(path)

            # Fallback: Navigate through input metadata to check if this is an array field
            current = @input_meta
            path.each_with_index do |segment, idx|
              return false unless current.is_a?(Hash)

              if idx == 0
                # First segment should be array input
                current = current[segment]
                return false unless current && current[:type] == :array

                current = current[:children] if current[:children]
              else
                # Subsequent segments are field access or nested array
                current = current[segment]
                return false unless current

                # If we encounter another array, we need to dive into its children
                current = current[:children] if current.is_a?(Hash) && current[:type] == :array && current[:children]
              end
            end

            true
          end

          def base_case?(case_expr)
            case_expr.condition.is_a?(Kumi::Syntax::Literal) &&
              case_expr.condition.value == true
          end

          def reduction_function?(fn_name)
            # Check registry for reducer functions

            registry_entry = Kumi::Registry.fetch(fn_name)
            # Check if entry has reducer metadata
            return true if registry_entry.respond_to?(:reducer?) && registry_entry.reducer?

            # Fallback: check if it's a known reduction function
            %i[sum max min avg count].include?(fn_name)
          rescue StandardError
            # If registry lookup fails, check known reduction functions
            %i[sum max min avg count].include?(fn_name)
          end

          def describe_source(expr)
            case expr
            when Kumi::Syntax::InputElementReference
              "input.#{expr.path.join('.')}"
            when Kumi::Syntax::DeclarationReference
              expr.name.to_s
            when Kumi::Syntax::Literal
              "literal_#{expr.value}"
            when Kumi::Syntax::CallExpression
              "#{expr.fn_name}_expression"
            else
              "unknown_expression"
            end
          end

          # Build compiler-compatible metadata structure
          def build_compiler_metadata(detector_metadata)
            # Build the structure the compiler expects
            {
              array_fields: @array_fields,
              vectorized_operations: extract_vectorized_operations(detector_metadata),
              reduction_operations: extract_reduction_operations(detector_metadata),
              nested_paths: @nested_paths,
              flattening_declarations: extract_flattening_declarations(detector_metadata),
              cascade_strategies: extract_cascade_strategies(detector_metadata),
              compilation_metadata: extract_compilation_metadata(detector_metadata)
            }
          end
          
          def extract_vectorized_operations(metadata)
            vectorized = {}
            metadata.each do |name, meta|
              next unless meta[:operation_type] == :vectorized
              
              vectorized[name] = {
                strategy: meta.dig(:vectorization, :strategy) || :unknown,
                array_source: meta[:array_source],
                operands: meta.dig(:vectorization, :operands) || [],
                dimension_info: meta.dig(:vectorization, :dimension_info)
              }
            end
            vectorized
          end
          
          def extract_reduction_operations(metadata)
            reductions = {}
            metadata.each do |name, meta|
              next unless meta[:operation_type] == :reduction
              
              reductions[name] = {
                function: meta.dig(:reduction, :function),
                input_source: meta.dig(:reduction, :input, :source),
                requires_flattening: meta.dig(:reduction, :input, :requires_flattening),
                array_source: meta[:array_source]
              }
            end
            reductions
          end
          
          def extract_flattening_declarations(metadata)
            flattening = {}
            metadata.each do |name, meta|
              if meta.dig(:compilation, :requires_flattening)
                flattening[name] = {
                  requires_flattening: true,
                  depth: meta[:array_source]&.[](:depth) || 1
                }
              end
            end
            flattening
          end
          
          def extract_cascade_strategies(metadata)
            strategies = {}
            metadata.each do |name, meta|
              next unless meta[:cascade]
              
              strategies[name] = {
                mode: meta.dig(:cascade, :processing, :mode),
                strategy: meta.dig(:cascade, :processing, :strategy),
                depth: meta.dig(:cascade, :processing, :depth)
              }
            end
            strategies
          end
          
          def extract_compilation_metadata(metadata)
            compilation = {}
            metadata.each do |name, meta|
              next unless meta[:compilation]
              
              compilation[name] = meta[:compilation]
            end
            compilation
          end

          # Helper methods for enhanced metadata

          def build_nested_paths_metadata(input_meta)
            nested_paths = {}
            input_meta.each do |root_name, root_meta|
              collect_nested_paths(nested_paths, [root_name], root_meta, 0, nil)
            end
            nested_paths
          end

          def collect_nested_paths(nested_paths, current_path, current_meta, array_depth, parent_access_mode = nil)
            current_access_mode = parent_access_mode

            # If current field is an array, increment depth and update access mode
            if current_meta[:type] == :array
              array_depth += 1
              # Use the access mode from this array, or inherit from parent
              current_access_mode = current_meta[:access_mode] || parent_access_mode || :object

              # Store path info for the array itself if we're in an array context
              if array_depth > 0 && current_path.length > 1 # Don't store root arrays
                nested_paths[current_path] = {
                  depth: array_depth,
                  access_mode: current_access_mode,
                  element_type: :array
                }
              end
            end

            if current_meta[:children]
              current_meta[:children].each do |child_name, child_meta|
                child_path = current_path + [child_name]

                # Store info for fields that are accessible through arrays
                if array_depth > 0
                  nested_paths[child_path] = {
                    depth: array_depth,
                    access_mode: current_access_mode,
                    element_type: child_meta[:type] || :any
                  }
                end

                # Recurse into children with the current access mode
                collect_nested_paths(nested_paths, child_path, child_meta, array_depth, current_access_mode)
              end
            elsif array_depth > 0
              # Leaf field in array context
              nested_paths[current_path] = {
                depth: array_depth,
                access_mode: current_access_mode,
                element_type: current_meta[:type] || :any
              }
            end
          end

          def find_array_fields(input_meta)
            result = {}
            input_meta.each do |name, meta|
              next unless meta[:type] == :array && meta[:children]

              result[name] = {
                element_fields: meta[:children].keys,
                element_types: meta[:children].transform_values { |v| v[:type] || :any }
              }
            end
            result
          end

          def build_path_info(path)
            # Try to compute depth by analyzing the path structure
            depth = 0
            last_array_access_mode = :object

            # Traverse the input metadata to calculate depth and track access modes
            current = @input_meta
            path.each_with_index do |segment, _idx|
              break unless current.is_a?(Hash) && current[segment]

              current = current[segment]
              next unless current[:type] == :array

              depth += 1
              # Capture the access mode from this array level
              last_array_access_mode = current[:access_mode] || :object
              current = current[:children] if current[:children]
            end

            # Use the last array's access mode we encountered
            access_mode = last_array_access_mode

            { depth: [depth, 1].max, access_mode: access_mode }
          end

          def scalar_compilation_hints
            {
              evaluation_mode: :direct,
              expects_array_input: false,
              produces_array_output: false,
              requires_flattening: false,
              requires_dimension_check: false,
              requires_hierarchical_logic: false
            }
          end

          def build_source_info(expr)
            case expr
            when Kumi::Syntax::InputElementReference
              path_info = @nested_paths[expr.path] || build_path_info(expr.path)
              {
                kind: :input_element,
                path: expr.path,
                dimensions: expr.path[0..-2], # All but the last element
                depth: path_info[:depth]
              }
            when Kumi::Syntax::DeclarationReference
              { kind: :declaration, name: expr.name }
            when Kumi::Syntax::Literal
              { kind: :literal, value: expr.value }
            when Kumi::Syntax::CallExpression
              { kind: :expression, operation: expr.fn_name }
            else
              { kind: :unknown }
            end
          end

          def extract_dimensions(analysis)
            case analysis[:operation_type]
            when :array_reference
              analysis[:array_source][:dimensions]
            when :vectorized
              if analysis[:vectorization]
                # Get dimensions from first array operand
                array_operand = analysis[:vectorization][:operands].find { |op| op[:type] == :array }
                if array_operand
                  array_operand.dig(:source, :dimensions) || []
                else
                  # Fallback to array_source if present
                  analysis[:array_source]&.[](:dimensions) || []
                end
              elsif analysis[:cascade]
                # Get from cascade array source
                analysis[:array_source][:dimensions]
              elsif analysis[:array_source]
                # Direct array source
                analysis[:array_source][:dimensions]
              else
                []
              end
            when :reduction
              # Reductions have array sources too
              analysis[:array_source]&.[](:dimensions) || []
            else
              []
            end
          end

          def check_dimension_compatibility(dimensions_list)
            return { compatible: true, mode: :scalar } if dimensions_list.empty?

            if dimensions_list.uniq.length == 1
              return { compatible: true, mode: :same_level,
                       primary_dimension: dimensions_list.first }
            end

            # Check for hierarchical compatibility
            sorted = dimensions_list.uniq.sort_by(&:length)
            is_hierarchical = sorted.each_cons(2).all? do |shorter, longer|
              longer[0, shorter.length] == shorter
            end

            if is_hierarchical
              {
                compatible: true,
                mode: :hierarchical,
                primary_dimension: sorted.last,
                all_dimensions: sorted
              }
            else
              {
                compatible: false,
                mode: :incompatible,
                primary_dimension: dimensions_list.first,
                all_dimensions: dimensions_list.uniq
              }
            end
          end
        end
      end
    end
  end
end
