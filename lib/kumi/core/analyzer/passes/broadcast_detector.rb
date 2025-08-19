# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Detects which operations should be broadcast over arrays
        # DEPENDENCIES: :input_metadata, :declarations
        # PRODUCES: :broadcasts
        class BroadcastDetector < PassBase
          def run(errors)
            input_meta = get_state(:input_metadata) || {}
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
              nested_prefixes: nested_paths.keys.map { |segs| segs.join(".") },  # For DimTracer string matching
              array_prefixes: array_fields.keys.map(&:to_s),  # For DimTracer string matching
              flattening_declarations: {},  # Track which declarations need flattening
              cascade_strategies: {}       # Pre-computed cascade processing strategies
            }

            # Track which values are vectorized for type inference
            vectorized_values = {}

            # Analyze traits first, then values (to handle dependencies)
            traits = definitions.select { |_name, decl| decl.is_a?(Kumi::Syntax::TraitDeclaration) }
            values = definitions.select { |_name, decl| decl.is_a?(Kumi::Syntax::ValueDeclaration) }

            (traits.to_a + values.to_a).each do |name, decl|
              result = analyze_value_vectorization(name, decl.expression, array_fields, nested_paths, vectorized_values, errors,
                                                   definitions)

              puts "#{name}: #{result[:type]} #{format_broadcast_info(result)}" if ENV["DEBUG_BROADCAST_CLEAN"]

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

              # Removed: compilation metadata is unused; reintroduce when lowering consumes it.
            end

            # Update state with broadcasts metadata for DimTracer use
            @state = state.with(:broadcasts, compiler_metadata.freeze)
            @state
          end

          private

          def infer_argument_scope(arg, array_fields, nested_paths)
            # Use unified DimTracer for dimensional analysis
            trace_result = DimTracer.trace(arg, @state)
            trace_result[:dims]
          end

          def format_broadcast_info(result)
            case result[:type]
            when :vectorized
              info = result[:info]
              "→ #{info[:source]} (path: #{info[:path]&.join('.')})"
            when :reduction
              info = result[:info]
              "→ fn:#{info[:function]} (arg: #{info[:argument]&.class&.name&.split('::')&.last})"
            when :scalar
              "→ scalar"
            else
              "→ #{result[:info]}"
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
              current_access_mode = current_meta[:access_mode] || :field # Default to :field if not specified
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
            # Get node metadata from node_index instead of legacy registry
            node_index = get_state(:node_index, required: false)
            entry_metadata = node_index&.dig(expr.object_id, :metadata) || {}

            # Use metadata fn_class if available, otherwise resolve from RegistryV2
            fn_class = entry_metadata[:fn_class] || get_function_class(expr, entry_metadata)
            is_reducer = (fn_class == :aggregate)
            is_structure = (fn_class == :structure)

            # 1) Analyze all args once
            arg_infos = expr.args.map do |arg|
              analyze_argument_vectorization(arg, array_fields, nested_paths, vectorized_values, definitions)
            end
            vec_idx   = arg_infos.each_index.select { |i| arg_infos[i][:vectorized] }
            vec_any   = !vec_idx.empty?

            # # 2) Special form: cascade_and (vectorized if any trait arg is vectorized)
            # if expr.fn_name == :cascade_and
            #   vectorized_trait = expr.args.find do |arg|
            #     arg.is_a?(Kumi::Syntax::DeclarationReference) && vectorized_values[arg.name]&.[](:vectorized)
            #   end
            #   if vectorized_trait
            #     return { type: :vectorized,
            #              info: { source: :cascade_condition_with_vectorized_trait, trait: vectorized_trait&.name } }
            #   end

            #   return { type: :scalar }
            # end

            # 3) Reducers: only reduce when the input is actually vectorized
            if is_reducer
              return { type: :scalar } unless vec_any

              # which args were vectorized?
              flatten_indices = vec_idx.dup
              vectorized_arg_index = vec_idx.first
              argument_ast = expr.args[vectorized_arg_index]

              src_info = arg_infos[vectorized_arg_index]

              return {
                type: :reduction,
                info: {
                  function: expr.fn_name,
                  source: src_info[:source],
                  argument: argument_ast, # << keep AST of the vectorized argument
                  flatten_argument_indices: flatten_indices
                }
              }
            end

            # 4) Structure (non-reducer) functions like `size`
            if is_structure
              # If any arg is itself a PURE reducer call (e.g., size(sum(x))), the inner collapses first ⇒ outer is scalar
              # But dual-nature functions (both reducer AND structure) should be treated as structure functions when nested
              return { type: :scalar } if expr.args.any? do |a|
                if a.is_a?(Kumi::Syntax::CallExpression)
                  arg_metadata = node_index&.dig(a.object_id, :metadata) || {}
                  arg_fn_class = arg_metadata[:fn_class] || get_function_class(a, arg_metadata)
                  arg_fn_class == :aggregate && arg_fn_class != :structure # Pure reducer only
                else
                  false
                end
              end

              # Structure fn over a vectorized element path ⇒ per-parent vectorization
              return { type: :scalar } unless vec_any

              src_info     = arg_infos[vec_idx.first]
              parent_scope = src_info[:parent_scope] || src_info[:source] # fallback if analyzer encodes parent separately
              return {
                type: :vectorized,
                info: {
                  operation: expr.fn_name,
                  source: src_info[:source],
                  parent_scope: parent_scope,
                  vectorized_args: vec_idx.to_h { |i| [i, true] }
                }
              }

              # Structure fn over a scalar/materialized container ⇒ scalar

            end

            # 5) Generic vectorized map (non-structure, non-reducer)
            if vec_any
              # Dimension / source compatibility check
              sources = vec_idx.map { |i| arg_infos[i][:array_source] }.compact.uniq
              if sources.size > 1
                # Cross-scope operation detected - mark it for join handling in LowerToIR
                return {
                  type: :vectorized,
                  info: {
                    cross_scope: true,
                    sources: sources,
                    requires_join: true,
                    dimensions: vec_idx.map { |i| arg_infos[i][:dimension] || [arg_infos[i][:array_source]] },
                    vec_idx: vec_idx,
                    array_source: sources.first # Use first source as primary for compatibility
                  }
                }
              end

              return {
                type: :vectorized,
                info: {
                  operation: expr.fn_name,
                  source: arg_infos[vec_idx.first][:source],
                  vectorized_args: vec_idx.to_h { |i| [i, true] }
                }
              }
            end

            # 6) Pure scalar
            { type: :scalar }
          end

          def get_function_class(expr, metadata)
            # Resolve function class from RegistryV2 and store in metadata for future passes
            fn_name = resolved_fn_name(metadata, expr)
            begin
              function = registry_v2.resolve(fn_name.to_s, arity: expr.args.size)
              fn_class = function.class_sym
              # Store in metadata for future reference
              metadata[:fn_class] = fn_class if metadata
              fn_class
            rescue StandardError => e
              if ENV["DEBUG_BROADCAST"]
                puts("  BroadcastDetector call_id=#{begin
                  expr.object_id
                rescue StandardError
                  'unknown'
                end} fn_name=#{fn_name} status=resolve_failed error=#{e.message}")
              end
              :scalar # Default to scalar for unknown functions
            end
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
              # Recursively check nested call
              result = analyze_value_vectorization(nil, arg, array_fields, nested_paths, vectorized_values, [], definitions)
              # Handle different result types appropriately
              case result[:type]
              when :reduction
                # Reductions can produce vectors if they preserve some dimensions
                # This aligns with lower_to_ir logic for grouped reductions
                info = result[:info]
                if info && info[:argument]
                  # Check if the reduction argument has array scope that would be preserved
                  arg_scope = infer_argument_scope(info[:argument], array_fields, nested_paths)
                  if arg_scope.length > 1
                    # Multi-dimensional reduction - likely preserves outer dimension (per-player)
                    { vectorized: true, source: :grouped_reduction, array_source: arg_scope.first }
                  else
                    # Single dimension or scalar reduction
                    { vectorized: false, source: :scalar_from_reduction }
                  end
                else
                  { vectorized: false, source: :scalar_from_reduction }
                end
              when :vectorized
                { vectorized: true, source: :expression }
              else
                { vectorized: false, source: :scalar }
              end

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
                  # Mark for scalar handling but don't error - let ScopeResolutionPass handle it
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
                  # Multiple definite dimensional sources - mark for scalar handling
                  puts "  -> MARKING FOR SCALAR HANDLING" if ENV["DEBUG_CASCADE"]
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
