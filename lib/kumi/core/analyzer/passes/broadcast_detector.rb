# frozen_string_literal: true

module Kumi
  module Core
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

            # Build nested paths metadata for nested array traversal
            nested_paths = build_nested_paths_metadata(input_meta)

            # Build compiler metadata
            compiler_metadata = {
              array_fields: array_fields,
              vectorized_operations: {},
              reduction_operations: {},
              nested_paths: nested_paths,
              flattening_declarations: {},  # Track which declarations need flattening
              cascade_strategies: {},       # Pre-computed cascade processing strategies
              compilation_metadata: {}      # Pre-computed compilation decisions
            }

            # Track which values are vectorized for type inference
            vectorized_values = {}

            # Analyze traits first, then values (to handle dependencies)
            traits = definitions.select { |_name, decl| decl.is_a?(Kumi::Syntax::TraitDeclaration) }
            values = definitions.select { |_name, decl| decl.is_a?(Kumi::Syntax::ValueDeclaration) }

            (traits.to_a + values.to_a).each do |name, decl|
              result = analyze_value_vectorization(name, decl.expression, array_fields, nested_paths, vectorized_values, errors,
                                                   definitions)

              case result[:type]
              when :vectorized
                compiler_metadata[:vectorized_operations][name] = result[:info]

                # If this is a cascade with processing strategy, store it separately for easy compiler access
                compiler_metadata[:cascade_strategies][name] = result[:info][:processing_strategy] if result[:info][:processing_strategy]

                # Store array source information for dimension checking
                array_source = extract_array_source(result[:info], array_fields)
                vectorized_values[name] = { vectorized: true, array_source: array_source }
              when :reduction
                compiler_metadata[:reduction_operations][name] = result[:info]
                # Mark this specific declaration as needing flattening for its argument
                compiler_metadata[:flattening_declarations][name] = result[:info]
                # Reduction produces scalar, not vectorized
                vectorized_values[name] = { vectorized: false }
              end

              # Pre-compute compilation metadata for each declaration
              compilation_meta = compute_compilation_metadata(
                name, decl, compiler_metadata, vectorized_values, array_fields
              )
              compiler_metadata[:compilation_metadata][name] = compilation_meta
            end

            state.with(:broadcasts, compiler_metadata.freeze)
          end

          private

          def compute_compilation_metadata(name, _decl, compiler_metadata, _vectorized_values, _array_fields)
            metadata = {
              operation_mode: :broadcast, # Default mode
              is_vectorized: false,
              vectorization_context: {},
              cascade_info: {},
              function_call_strategy: {}
            }

            # Check if this declaration is vectorized
            if compiler_metadata[:vectorized_operations][name]
              metadata[:is_vectorized] = true
              vectorized_info = compiler_metadata[:vectorized_operations][name]

              # Pre-compute vectorization context
              metadata[:vectorization_context] = {
                has_vectorized_args: true,
                needs_broadcasting: true,
                array_structure_depth: estimate_array_depth(vectorized_info, compiler_metadata[:nested_paths])
              }

              # If this is a cascade, pre-compute cascade processing strategy
              if vectorized_info[:source] == :cascade_with_vectorized_conditions_or_results
                strategy = compiler_metadata[:cascade_strategies][name]
                metadata[:cascade_info] = {
                  is_vectorized: true,
                  processing_mode: strategy&.dig(:mode) || :hierarchical,
                  needs_hierarchical_processing: needs_hierarchical_processing?(strategy)
                }
              end
            end

            # Check if this declaration needs flattening
            if compiler_metadata[:flattening_declarations][name]
              metadata[:operation_mode] = :flatten
              flattening_info = compiler_metadata[:flattening_declarations][name]

              metadata[:function_call_strategy] = {
                flattening_required: true,
                flatten_argument_indices: flattening_info[:flatten_argument_indices] || [0],
                result_structure: :scalar
              }
            end

            metadata
          end

          def estimate_array_depth(vectorized_info, nested_paths)
            case vectorized_info[:source]
            when :nested_array_access
              path = vectorized_info[:path]
              nested_paths[path]&.dig(:array_depth) || 1
            when :array_field_access
              1
            else
              1
            end
          end

          def needs_hierarchical_processing?(strategy)
            return false unless strategy

            case strategy[:mode]
            when :nested_array, :deep_nested_array
              true
            else
              false
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

          def build_nested_paths_metadata(input_meta)
            nested_paths = {}

            # Recursively build all possible nested paths from input metadata
            input_meta.each do |root_name, root_meta|
              collect_nested_paths(nested_paths, [root_name], root_meta, 0, nil)
            end

            nested_paths
          end

          def collect_nested_paths(nested_paths, current_path, current_meta, array_depth, parent_access_mode = nil)
            # If current field is an array, increment array depth and track its access_mode
            current_access_mode = parent_access_mode
            if current_meta[:type] == :array
              array_depth += 1
              current_access_mode = current_meta[:access_mode] || :object # Default to :object if not specified
            end

            # If this field has children, recurse into them
            if current_meta[:children]
              current_meta[:children].each do |child_name, child_meta|
                child_path = current_path + [child_name]

                # Create metadata for this path if it involves arrays
                if array_depth.positive?
                  nested_paths[child_path] =
                    build_path_metadata(child_path, child_meta, array_depth, current_access_mode)
                end

                # Recurse into child's children
                collect_nested_paths(nested_paths, child_path, child_meta, array_depth, current_access_mode)
              end
            elsif array_depth.positive?
              # Leaf field - create metadata if it involves arrays
              nested_paths[current_path] = build_path_metadata(current_path, current_meta, array_depth, current_access_mode)
            end
          end

          def build_path_metadata(_path, field_meta, array_depth, parent_access_mode = nil)
            {
              array_depth: array_depth,
              element_type: field_meta[:type] || :any,
              operation_mode: :broadcast, # Default mode - may be overridden for aggregations
              result_structure: array_depth > 1 ? :nested_array : :array,
              access_mode: parent_access_mode # Access mode of the parent array field
            }
          end

          def analyze_value_vectorization(name, expr, array_fields, nested_paths, vectorized_values, errors, definitions = nil)
            case expr
            when Kumi::Syntax::InputElementReference
              # Check if this path exists in nested_paths metadata (supports nested arrays)
              if nested_paths.key?(expr.path)
                { type: :vectorized, info: { source: :nested_array_access, path: expr.path, nested_metadata: nested_paths[expr.path] } }
              # Fallback to old array_fields detection for backward compatibility
              elsif array_fields.key?(expr.path.first)
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
              analyze_call_vectorization(name, expr, array_fields, nested_paths, vectorized_values, errors, definitions)

            when Kumi::Syntax::CascadeExpression
              analyze_cascade_vectorization(name, expr, array_fields, nested_paths, vectorized_values, errors, definitions)

            else
              { type: :scalar }
            end
          end

          def analyze_call_vectorization(_name, expr, array_fields, nested_paths, vectorized_values, errors, definitions = nil)
            # Check if this is a reduction function using function registry metadata
            if Kumi::Registry.reducer?(expr.fn_name)
              # Only treat as reduction if the argument is actually vectorized
              arg_info = analyze_argument_vectorization(expr.args.first, array_fields, nested_paths, vectorized_values, definitions)
              if arg_info[:vectorized]
                # Pre-compute which argument indices need flattening
                flatten_indices = []
                expr.args.each_with_index do |arg, index|
                  arg_vectorization = analyze_argument_vectorization(arg, array_fields, nested_paths, vectorized_values, definitions)
                  flatten_indices << index if arg_vectorization[:vectorized]
                end

                { type: :reduction, info: {
                  function: expr.fn_name,
                  source: arg_info[:source],
                  argument: expr.args.first,
                  flatten_argument_indices: flatten_indices
                } }
              else
                # Not a vectorized reduction - just a regular function call
                { type: :scalar }
              end

            else

              # Special case: cascade_and takes individual trait arguments
              if expr.fn_name == :cascade_and
                # Check if any of the individual arguments are vectorized traits
                vectorized_trait = expr.args.find do |arg|
                  arg.is_a?(Kumi::Syntax::DeclarationReference) && vectorized_values[arg.name]&.[](:vectorized)
                end
                if vectorized_trait
                  return { type: :vectorized, info: { source: :cascade_condition_with_vectorized_trait, trait: vectorized_trait.name } }
                end
              end

              # Analyze arguments to determine function behavior
              arg_infos = expr.args.map do |arg|
                analyze_argument_vectorization(arg, array_fields, nested_paths, vectorized_values, definitions)
              end

              if arg_infos.any? { |info| info[:vectorized] }
                # Check for dimension mismatches when multiple arguments are vectorized
                vectorized_sources = arg_infos.select { |info| info[:vectorized] }.filter_map { |info| info[:array_source] }.uniq

                if vectorized_sources.length > 1
                  # Multiple different array sources - this is a dimension mismatch
                  # Generate enhanced error message with type information
                  enhanced_message = build_dimension_mismatch_error(expr, arg_infos, array_fields, vectorized_sources)

                  report_error(errors, enhanced_message, location: expr.loc, type: :semantic)
                  return { type: :scalar } # Treat as scalar to prevent further errors
                end

                # Check if this is a structure function that should work on the array as-is
                if structure_function?(expr.fn_name)
                  # Structure functions like size should work on structure as-is (scalar)
                  { type: :scalar }
                else
                  # This is a vectorized operation - broadcast over elements
                  { type: :vectorized, info: {
                    operation: expr.fn_name,
                    vectorized_args: arg_infos.map.with_index { |info, i| [i, info[:vectorized]] }.to_h
                  } }
                end
              else
                # No vectorized arguments - regular scalar function
                { type: :scalar }
              end
            end
          end

          def structure_function?(fn_name)
            # Check if function is marked as working on structure (not broadcast over elements)
            Kumi::Registry.structure_function?(fn_name)
          end

          def analyze_argument_vectorization(arg, array_fields, nested_paths, vectorized_values, definitions = nil)
            case arg
            when Kumi::Syntax::InputElementReference
              # Check nested paths first (supports nested arrays)
              if nested_paths.key?(arg.path)
                { vectorized: true, source: :nested_array_field, array_source: arg.path.first }
              # Fallback to old array_fields detection for backward compatibility
              elsif array_fields.key?(arg.path.first)
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
              result = analyze_value_vectorization(nil, arg, array_fields, nested_paths, vectorized_values, [], definitions)
              { vectorized: result[:type] == :vectorized, source: :expression }

            else
              { vectorized: false }
            end
          end

          def extract_array_source(info, _array_fields)
            case info[:source]
            when :array_field_access
              info[:path]&.first
            when :cascade_condition_with_vectorized_trait
              # For cascades, we'd need to trace back to the original source
              nil # TODO: Could be enhanced to trace through trait dependencies
            end
          end

          def analyze_cascade_vectorization(name, expr, array_fields, nested_paths, vectorized_values, errors, definitions = nil)
            # Enhanced cascade analysis with dimensional intelligence
            condition_sources = []
            result_sources = []
            condition_dimensions = []
            result_dimensions = []
            is_vectorized = false

            if ENV["DEBUG_CASCADE"]
              puts "DEBUG: analyze_cascade_vectorization for #{name}"
              puts "  Expression: #{expr.inspect}"
              puts "  Cases: #{expr.cases.length}"
            end

            expr.cases.each do |case_expr|
              # Analyze result expression
              result_info = analyze_value_vectorization(nil, case_expr.result, array_fields, nested_paths, vectorized_values, errors,
                                                        definitions)
              if result_info[:type] == :vectorized
                is_vectorized = true
                source, dimension = trace_dimensional_source(case_expr.result, result_info, vectorized_values, array_fields, definitions)
                result_sources << source
                result_dimensions << dimension
              end

              # Analyze condition expression
              condition_info = analyze_value_vectorization(nil, case_expr.condition, array_fields, nested_paths, vectorized_values, errors,
                                                           definitions)
              next unless condition_info[:type] == :vectorized

              is_vectorized = true

              # Special handling for cascade_and to check all arguments for dimensional conflicts
              if ENV["DEBUG_CASCADE"]
                puts "  Checking condition type: #{case_expr.condition.class}"
                puts "  Condition fn_name: #{case_expr.condition.fn_name}" if case_expr.condition.is_a?(Kumi::Syntax::CallExpression)
              end

              if case_expr.condition.is_a?(Kumi::Syntax::CallExpression) && case_expr.condition.fn_name == :cascade_and
                puts "  -> ENTERING CASCADE_AND SPECIAL HANDLING" if ENV["DEBUG_CASCADE"]
                # For cascade_and, check all individual trait references for dimensional conflicts
                cascade_sources = []
                cascade_dimensions = []

                puts "  cascade_and args: #{case_expr.condition.args.map(&:class)}" if ENV["DEBUG_CASCADE"]

                case_expr.condition.args.each do |arg|
                  puts "  Processing arg: #{arg.inspect}" if ENV["DEBUG_CASCADE"]
                  next unless arg.is_a?(Kumi::Syntax::DeclarationReference)

                  puts "  Looking up declaration: #{arg.name}" if ENV["DEBUG_CASCADE"]
                  decl = definitions[arg.name] if definitions
                  if decl
                    puts "  Found declaration, tracing source..." if ENV["DEBUG_CASCADE"]
                    arg_source, arg_dimension = trace_dimensional_source(decl.expression, condition_info, vectorized_values,
                                                                         array_fields, definitions)
                    puts "  Traced source: #{arg_source}, dimension: #{arg_dimension}" if ENV["DEBUG_CASCADE"]
                    cascade_sources << arg_source
                    cascade_dimensions << arg_dimension
                  elsif ENV["DEBUG_CASCADE"]
                    puts "  Declaration not found: #{arg.name}"
                  end
                end

                # Check for conflicts between cascade_and arguments
                unique_sources = cascade_sources.uniq
                unique_dimensions = cascade_dimensions.uniq

                if ENV["DEBUG_CASCADE"]
                  puts "  cascade_sources: #{cascade_sources.inspect}"
                  puts "  cascade_dimensions: #{cascade_dimensions.inspect}"
                  puts "  unique_sources: #{unique_sources.inspect}"
                  puts "  unique_dimensions: #{unique_dimensions.inspect}"
                end

                # Check for dimensional conflicts - either different sources OR incompatible dimensions
                has_source_conflict = unique_sources.length > 1 && unique_sources.none? { |s| s.to_s.include?("unknown") }
                has_dimension_conflict = unique_dimensions.length > 1 && !valid_hierarchical_broadcasting?(unique_dimensions)

                if ENV["DEBUG_CASCADE"]
                  puts "  has_source_conflict: #{has_source_conflict}"
                  puts "  has_dimension_conflict: #{has_dimension_conflict}"
                  if unique_dimensions.length > 1
                    puts "  valid_hierarchical_broadcasting?: #{valid_hierarchical_broadcasting?(unique_dimensions)}"
                  end
                end

                if has_source_conflict || has_dimension_conflict
                  # Multiple different sources or incompatible dimensions in same cascade_and - this is invalid
                  if ENV["DEBUG_CASCADE"]
                    puts "  -> FOUND CASCADE_AND DIMENSIONAL CONFLICT:"
                    puts "    Sources: #{unique_sources.inspect}"
                    puts "    Dimensions: #{unique_dimensions.inspect}"
                    puts "    Source conflict: #{has_source_conflict}"
                    puts "    Dimension conflict: #{has_dimension_conflict}"
                  end
                  report_cascade_dimension_mismatch(errors, expr, unique_sources, unique_dimensions)
                  return { type: :scalar }
                end

                # Use the first valid source as the overall condition source
                condition_sources.concat(cascade_sources)
                condition_dimensions.concat(cascade_dimensions)
              else
                source, dimension = trace_dimensional_source(case_expr.condition, condition_info, vectorized_values, array_fields,
                                                             definitions)
                condition_sources << source
                condition_dimensions << dimension
              end
            end

            if is_vectorized
              # Validate dimensional compatibility
              all_sources = (condition_sources + result_sources).compact.uniq
              all_dimensions = (condition_dimensions + result_dimensions).compact.uniq

              if ENV["DEBUG_CASCADE"]
                puts "  is_vectorized: true"
                puts "  condition_sources: #{condition_sources.inspect}"
                puts "  result_sources: #{result_sources.inspect}"
                puts "  condition_dimensions: #{condition_dimensions.inspect}"
                puts "  result_dimensions: #{result_dimensions.inspect}"
                puts "  all_sources: #{all_sources.inspect}"
                puts "  all_dimensions: #{all_dimensions.inspect}"
              end

              # For now, be less strict about dimensional validation
              # Only report mismatches for clearly incompatible sources
              definite_sources = all_sources.reject { |s| s.to_s.include?("unknown") || s.to_s.include?("operation") }

              if ENV["DEBUG_CASCADE"]
                puts "  definite_sources: #{definite_sources.inspect}"
                puts "  definite_sources.length: #{definite_sources.length}"
              end

              if definite_sources.length > 1
                # Check if sources are in valid hierarchical relationship (parent-child broadcasting)
                is_valid_hierarchical = valid_hierarchical_broadcasting?(all_dimensions)
                puts "  valid_hierarchical_broadcasting?: #{is_valid_hierarchical}" if ENV["DEBUG_CASCADE"]
                unless is_valid_hierarchical
                  # Multiple definite dimensional sources - this is a real mismatch
                  puts "  -> REPORTING DIMENSIONAL MISMATCH" if ENV["DEBUG_CASCADE"]
                  report_cascade_dimension_mismatch(errors, expr, definite_sources, all_dimensions)
                  return { type: :scalar } # Treat as scalar to prevent further errors
                end
              end

              # Compute cascade processing strategy based on dimensional analysis
              processing_strategy = compute_cascade_processing_strategy(all_dimensions.first, nested_paths)

              { type: :vectorized, info: {
                source: :cascade_with_vectorized_conditions_or_results,
                dimensional_requirements: {
                  conditions: { sources: condition_sources.uniq, dimensions: condition_dimensions.uniq },
                  results: { sources: result_sources.uniq, dimensions: result_dimensions.uniq }
                },
                primary_dimension: all_dimensions.first,
                nested_paths: extract_nested_paths_from_dimensions(all_dimensions.first, nested_paths),
                processing_strategy: processing_strategy
              } }
            else
              { type: :scalar }
            end
          end

          def trace_dimensional_source(expr, info, vectorized_values, array_fields, definitions = nil)
            # Trace dimensional source by examining the AST node directly
            case expr
            when Kumi::Syntax::InputElementReference
              # Direct array field access
              source = expr.path.first
              dimension = expr.path
              [source, dimension]
            when Kumi::Syntax::DeclarationReference
              # Reference to another declaration - look up its dimensional info
              if vectorized_values[expr.name]
                vectorized_info = vectorized_values[expr.name]
                if vectorized_info[:array_source]
                  [vectorized_info[:array_source], [vectorized_info[:array_source]]]
                else
                  # Need to trace through the declaration's expression to find the real source
                  decl = definitions[expr.name] if definitions
                  if decl
                    # Recursively trace the declaration's expression
                    trace_dimensional_source(decl.expression, info, vectorized_values, array_fields, definitions)
                  else
                    [:unknown_vectorized_operation, [:unknown_vectorized_operation]]
                  end
                end
              else
                [:unknown_declaration, [:unknown_declaration]]
              end
            when Kumi::Syntax::CallExpression
              # For call expressions, trace through the arguments to find dimensional source
              first_vectorized_arg = expr.args.find do |arg|
                arg_info = analyze_argument_vectorization(arg, array_fields, {}, vectorized_values, definitions)
                arg_info[:vectorized]
              end

              if first_vectorized_arg
                trace_dimensional_source(first_vectorized_arg, info, vectorized_values, array_fields, definitions)
              else
                [:operation_unknown, [:operation_unknown]]
              end
            else
              [:unknown_expr, [:unknown_expr]]
            end
          end

          def extract_dimensional_info_with_context(info, _array_fields, _nested_paths, vectorized_values)
            case info[:source]
            when :array_field_access, :nested_array_access
              # Direct array field access - use the path
              source = info[:path]&.first
              dimension = info[:path]
              [source, dimension]
            when :vectorized_declaration
              # Reference to another vectorized declaration - look it up
              if info[:name] && vectorized_values[info[:name]]
                vectorized_info = vectorized_values[info[:name]]
                if vectorized_info[:array_source]
                  # This declaration references an array field, use that source
                  [vectorized_info[:array_source], [vectorized_info[:array_source]]]
                else
                  # This is a derived vectorized value, try to trace its source
                  [:vectorized_reference, [:vectorized_reference]]
                end
              else
                [:unknown_declaration, [:unknown_declaration]]
              end
            else
              # Operations and other cases - try to extract from operation args
              if info[:operation] && info[:vectorized_args]
                # This is an operation result - trace the vectorized arguments
                # For now, assume operations inherit the dimension of their first vectorized arg
                [:operation_result, [:operation_result]]
              else
                [:unknown, [:unknown]]
              end
            end
          end

          def extract_dimensional_source(info, _array_fields)
            case info[:source]
            when :array_field_access
              info[:path]&.first
            when :nested_array_access
              info[:path]&.first
            when :vectorized_declaration, :vectorized_value
              # Try to extract from the vectorized value info if available
              if info[:name] && info.dig(:info, :path)
                info[:info][:path].first
              else
                :vectorized_reference
              end
            else
              # For operations and other cases, try to infer from vectorized args
              if info[:vectorized_args]
                # This is likely an operation - we should look at its arguments
                :operation_result
              else
                :unknown
              end
            end
          end

          def extract_dimensions(info, _array_fields, _nested_paths)
            case info[:source]
            when :array_field_access
              info[:path]
            when :nested_array_access
              info[:path]
            when :vectorized_declaration, :vectorized_value
              # Try to extract from the vectorized value info if available
              if info[:name] && info.dig(:info, :path)
                info[:info][:path]
              else
                [:vectorized_reference]
              end
            else
              # For operations, try to infer from the operation context
              if info[:vectorized_args]
                # This is likely an operation - we should trace its arguments
                [:operation_result]
              else
                [:unknown]
              end
            end
          end

          def extract_nested_paths_from_dimensions(dimension, nested_paths)
            return nil unless dimension.is_a?(Array)

            nested_paths[dimension]
          end

          # Check if dimensions represent valid hierarchical broadcasting (parent-to-child)
          # Example: [:regions, :offices, :teams] can broadcast to [:regions, :offices, :teams, :employees]
          def valid_hierarchical_broadcasting?(dimensions)
            puts "    DEBUG valid_hierarchical_broadcasting?: dimensions=#{dimensions.inspect}" if ENV["DEBUG_CASCADE"]

            return true if dimensions.length <= 1

            # Extract structural paths by removing the final field name from each dimension
            # This allows us to identify that [:regions, :offices, :teams, :performance_score]
            # and [:regions, :offices, :teams, :employees, :rating] both have the structural
            # path [:regions, :offices, :teams] and [:regions, :offices, :teams, :employees] respectively
            structural_paths = dimensions.map do |dim|
              if dim.length > 1
                dim[0..-2] # Remove the final field name
              else
                dim
              end
            end.uniq

            puts "    structural_paths: #{structural_paths.inspect}" if ENV["DEBUG_CASCADE"]

            # Group dimensions by their root (first element)
            root_groups = structural_paths.group_by(&:first)

            puts "    root_groups: #{root_groups.keys.inspect}" if ENV["DEBUG_CASCADE"]

            # All dimensions must come from the same root
            if root_groups.length > 1
              puts "    -> REJECT: Multiple roots" if ENV["DEBUG_CASCADE"]
              return false
            end

            # If all structural paths are the same, this is valid (same level)
            if structural_paths.length == 1
              puts "    -> ACCEPT: All dimensions at same structural level" if ENV["DEBUG_CASCADE"]
              return true
            end

            # Within the same root, check if we have valid parent-child relationships
            sorted_paths = structural_paths.sort_by(&:length)

            puts "    sorted structural paths: #{sorted_paths.inspect}" if ENV["DEBUG_CASCADE"]

            # Check if all structural paths form a valid hierarchical structure
            # For valid hierarchical broadcasting, structural paths should be related by parent-child relationships

            # Check if there are any actual parent-child relationships
            has_real_hierarchy = false

            (0...sorted_paths.length).each do |i|
              ((i + 1)...sorted_paths.length).each do |j|
                path1 = sorted_paths[i]
                path2 = sorted_paths[j]
                shorter, longer = [path1, path2].sort_by(&:length)

                next unless longer[0, shorter.length] == shorter

                puts "    Found parent-child relationship: #{shorter.inspect} → #{longer.inspect}" if ENV["DEBUG_CASCADE"]
                has_real_hierarchy = true
              end
            end

            puts "    has_real_hierarchy: #{has_real_hierarchy}" if ENV["DEBUG_CASCADE"]

            # Allow same-level dimensions or hierarchical relationships
            if !has_real_hierarchy && sorted_paths.length > 1
              puts "    -> REJECT: No parent-child relationships found - these are sibling branches" if ENV["DEBUG_CASCADE"]
              return false
            end

            puts "    -> ACCEPT: All dimensions compatible" if ENV["DEBUG_CASCADE"]
            true
          end

          def compute_cascade_processing_strategy(primary_dimension, nested_paths)
            return { mode: :scalar } unless primary_dimension

            # Determine structure depth from the dimension path
            structure_depth = primary_dimension.length

            # Determine processing mode based on structure complexity
            processing_mode = case structure_depth
                              when 0, 1
                                :simple_array     # Single-level array processing
                              when 2, 3, 4
                                :nested_array     # Multi-level nested array processing
                              else
                                :deep_nested_array # Very deep nesting (5+ levels)
                              end

            # Get nested path information for this dimension
            nested_path_info = nested_paths[primary_dimension]

            {
              mode: processing_mode,
              structure_depth: structure_depth,
              dimension_path: primary_dimension,
              element_processing: :cascade_conditional_logic,
              nested_path_info: nested_path_info
            }
          end

          def report_cascade_dimension_mismatch(errors, expr, sources, dimensions)
            puts "DEBUG: Dimensional analysis details:" if ENV["DEBUG_CASCADE"]
            puts "  Sources: #{sources.inspect}" if ENV["DEBUG_CASCADE"]
            puts "  Dimensions: #{dimensions.inspect}" if ENV["DEBUG_CASCADE"]
            puts "  Valid hierarchical? #{valid_hierarchical_broadcasting?(dimensions)}" if ENV["DEBUG_CASCADE"]

            message = "Cascade dimensional mismatch: Cannot mix arrays from different sources (#{sources.join(', ')}) " \
                      "with dimensions (#{dimensions.map(&:inspect).join(', ')}) in cascade conditions and results."
            report_error(errors, message, location: expr.loc, type: :semantic)
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
end
