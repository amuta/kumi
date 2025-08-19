# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Plans per-declaration execution scope and join/lift needs.
        # Determines the dimensional scope (array nesting level) for each declaration
        # based on vectorization metadata and input paths.
        #
        # DEPENDENCIES: :declarations, :input_metadata, :broadcasts
        # PRODUCES: :scope_plans, :decl_shapes
        class ScopeResolutionPass < PassBase
          include Kumi::Core::Analyzer::Plans

          def run(_errors)
            declarations = get_state(:declarations, required: true)
            input_metadata = get_state(:input_metadata, required: true)
            node_index = get_state(:node_index, required: true)
            broadcasts = get_state(:broadcasts) || {}
            dependencies = get_state(:dependencies) || {}
            
            puts "Available dependencies: #{dependencies.keys.inspect}" if ENV["DEBUG_SCOPE_RESOLUTION"]

            scope_plans = {}
            decl_shapes = {}

            initial_scopes = {}
            declarations.each do |name, decl|
              debug_output(name, decl) if ENV["DEBUG_SCOPE_RESOLUTION"]
              target_scope = infer_target_scope(name, decl, broadcasts, input_metadata)
              result_kind = determine_result_kind(name, target_scope, broadcasts)
              initial_scopes[name] = target_scope
              debug_result(target_scope, result_kind) if ENV["DEBUG_SCOPE_RESOLUTION"]
            end

            final_scopes = propagate_scope_constraints(initial_scopes, declarations, input_metadata)
            final_scopes.each do |name, target_scope|
              decl = declarations[name]
              result_kind = determine_result_kind(name, target_scope, broadcasts)
              
              # If this is a cascade and the hierarchy check fails, force scalar scope.
              if decl&.expression&.is_a?(Kumi::Syntax::CascadeExpression)
                unless valid_hierarchical_broadcasting?(decl, input_metadata)
                  target_scope = []
                  annotate_scalarized_cascade(name)
                end
              end
              
              plan = build_scope_plan(target_scope)
              scope_plans[name] = plan
              decl_shapes[name] = { scope: target_scope, result: result_kind }.freeze
            end

            # Populate node_index with inferred scopes for all expression nodes
            populate_node_index_scopes(node_index, final_scopes, declarations, input_metadata)

            # Return new state with scope information
            state.with(:scope_plans, scope_plans.freeze)
                 .with(:decl_shapes, decl_shapes.freeze)
          end

          private

          def propagate_scope_constraints(initial_scopes, declarations, input_metadata)
            scopes = initial_scopes.dup
            puts "\n=== Propagating scope constraints ===" if ENV["DEBUG_SCOPE_RESOLUTION"]

            declarations.each do |name, decl|
              case decl.expression
              when Kumi::Syntax::ArrayExpression
                propagate_from_array_expression(name, decl.expression, scopes, declarations, input_metadata)
              when Kumi::Syntax::CascadeExpression
                propagate_from_cascade_expression(name, decl.expression, scopes, declarations, input_metadata)
              end
            end

            puts "Final propagated scopes: #{scopes.inspect}" if ENV["DEBUG_SCOPE_RESOLUTION"]
            scopes
          end

          def propagate_from_array_expression(name, array_expr, scopes, declarations, input_metadata)
            puts "Analyzing array expression in #{name}: #{array_expr.elements.map(&:class)}" if ENV["DEBUG_SCOPE_RESOLUTION"]

            anchor_scope = nil
            declaration_refs = []

            array_expr.elements.each do |element|
              case element
              when Kumi::Syntax::InputElementReference
                path_scope = dims_from_path(element.path, input_metadata)
                puts "Found input anchor: #{element.path} -> scope #{path_scope}" if ENV["DEBUG_SCOPE_RESOLUTION"]
                anchor_scope = path_scope if path_scope.length > (anchor_scope&.length || 0)
              when Kumi::Syntax::DeclarationReference
                declaration_refs << element.name
              end
            end

            if anchor_scope && !anchor_scope.empty?
              declaration_refs.each do |ref_name|
                current_scope = scopes[ref_name] || []
                if anchor_scope.length > current_scope.length
                  puts "Propagating scope #{anchor_scope} to #{ref_name} (was #{current_scope})" if ENV["DEBUG_SCOPE_RESOLUTION"]
                  scopes[ref_name] = anchor_scope
                  propagate_to_dependencies(ref_name, anchor_scope, scopes, declarations, input_metadata)
                end
              end
            end
          end

          def propagate_from_cascade_expression(name, cascade_expr, scopes, declarations, input_metadata)
            puts "Analyzing cascade expression in #{name}" if ENV["DEBUG_SCOPE_RESOLUTION"]
            
            # Cascade should propagate its own scope to condition dependencies
            cascade_scope = scopes[name] || []
            return if cascade_scope.empty?
            
            puts "Propagating cascade scope #{cascade_scope} to condition dependencies" if ENV["DEBUG_SCOPE_RESOLUTION"]
            
            cascade_expr.cases.each do |case_expr|
              find_declaration_references(case_expr.condition).each do |ref_name|
                current_scope = scopes[ref_name] || []
                if cascade_scope.length > current_scope.length
                  puts "Propagating scope #{cascade_scope} to cascade condition #{ref_name} (was #{current_scope})" if ENV["DEBUG_SCOPE_RESOLUTION"]
                  scopes[ref_name] = cascade_scope
                  propagate_to_dependencies(ref_name, cascade_scope, scopes, declarations, input_metadata)
                end
              end
            end
          end

          def propagate_to_dependencies(decl_name, required_scope, scopes, declarations, input_metadata)
            return unless declarations[decl_name]
            
            decl = declarations[decl_name]
            puts "Propagating #{required_scope} into dependencies of #{decl_name}" if ENV["DEBUG_SCOPE_RESOLUTION"]
            
            case decl.expression
            when Kumi::Syntax::CascadeExpression
              decl.expression.cases.each do |case_expr|
                find_declaration_references(case_expr.condition).each do |ref_name|
                  current_scope = scopes[ref_name] || []
                  if required_scope.length > current_scope.length
                    puts "Propagating scope #{required_scope} to trait dependency #{ref_name}" if ENV["DEBUG_SCOPE_RESOLUTION"]
                    scopes[ref_name] = required_scope
                    update_reduction_scope_if_needed(ref_name, required_scope, declarations, input_metadata)
                  end
                end
              end
            end
          end

          def find_declaration_references(expr)
            refs = []
            case expr
            when Kumi::Syntax::DeclarationReference
              refs << expr.name
            when Kumi::Syntax::CallExpression
              expr.args.each { |arg| refs.concat(find_declaration_references(arg)) }
            when Kumi::Syntax::ArrayExpression
              expr.elements.each { |elem| refs.concat(find_declaration_references(elem)) }
            end
            refs
          end

          def update_reduction_scope_if_needed(decl_name, required_scope, declarations, input_metadata)
            decl = declarations[decl_name]
            return unless decl
            puts "Checking if #{decl_name} needs reduction scope update for #{required_scope}" if ENV["DEBUG_SCOPE_RESOLUTION"]
          end

          def debug_output(name, decl)
            puts "\n=== Resolving scope for #{name} ==="
            puts "Declaration: #{decl.inspect}"
          end

          def debug_result(target_scope, result_kind)
            puts "Target scope: #{target_scope.inspect}"
            puts "Result kind: #{result_kind.inspect}"
          end

          def build_scope_plan(target_scope)
            Scope.new(
              scope: target_scope,
              lifts: [], # Will be computed during IR lowering per call-site
              join_hint: nil, # Will be set to :zip when multiple vectorized args exist
              arg_shapes: {} # Optional: filled during lowering
            )
          end

          def determine_result_kind(name, target_scope, broadcasts)
            return :scalar if broadcasts.dig(:reduction_operations, name)
            return :scalar if target_scope.empty?

            { array: :dense }
          end

          # Derive scope from vectorization metadata or from deepest input path
          def infer_target_scope(name, decl, broadcasts, input_metadata)
            # First check vectorized operations
            vec = broadcasts.dig(:vectorized_operations, name)
            if vec
              puts "Vectorization info: #{vec.inspect}" if ENV["DEBUG_SCOPE_RESOLUTION"]

              case vec[:source]
              when :nested_array_access, :array_field_access
                path = vec[:path] || []
                return dims_from_path(path, input_metadata)
              when :cascade_with_vectorized_conditions_or_results,
                   :cascade_condition_with_vectorized_trait
                # Extract scope from dimensional requirements for vectorized cascades
                if vec[:dimensional_requirements]
                  # Check both conditions and results for sources
                  condition_sources = vec[:dimensional_requirements][:conditions]&.[](:sources) || []
                  result_sources = vec[:dimensional_requirements][:results]&.[](:sources) || []
                  all_sources = (condition_sources + result_sources).uniq
                  return all_sources.first || []  # Use first source as target scope
                end
                # Fallback: derive from first input path seen in expression
                path = find_first_input_path(decl.expression) || []
                return dims_from_path(path, input_metadata)
              else
                return []
              end
            end

            # Check if this is a reduction operation that should preserve some scope
            red = broadcasts.dig(:reduction_operations, name)
            if red
              puts "Reduction info: #{red.inspect}" if ENV["DEBUG_SCOPE_RESOLUTION"]
              
              # Infer the natural scope for this reduction
              # For expressions like fn(:any?, input.players.score_matrices.session.points > 1000)
              # we want to reduce over session dimension but preserve the players dimension
              scope = infer_reduction_target_scope(decl.expression, input_metadata)
              puts "Inferred reduction target scope: #{scope.inspect}" if ENV["DEBUG_SCOPE_RESOLUTION"]
              return scope
            end

            return []
          end

          def infer_reduction_target_scope(expr, input_metadata)
            # For reduction expressions, we need to analyze the argument to the reducer
            # and determine which dimensions should be preserved vs reduced
            case expr
            when Kumi::Syntax::CallExpression
              if reducer_function?(expr.fn_name)
                # Find the argument being reduced
                arg = expr.args.first
                if arg
                  # Get the full scope from the argument
                  full_scope = infer_scope_from_argument(arg, input_metadata)
                  
                  # For array reductions, we typically want to preserve
                  # the outermost dimension (e.g., keep :players, reduce :score_matrices/:session)
                  if full_scope.length > 1
                    return full_scope[0..0]  # Keep only the first dimension
                  end
                end
              else
                # Recursively check if any argument contains a reducer
                # This handles cases like (fn(:sum, ...) >= 3500)
                expr.args.each do |arg|
                  nested_scope = infer_reduction_target_scope(arg, input_metadata)
                  return nested_scope if !nested_scope.empty?
                end
              end
            end
            []
          end

          def reducer_function?(fn_name)
            # Use RegistryV2 to check if function is an aggregate (reducer)
            function = registry_v2.resolve(fn_name.to_s, arity: nil)
            function.class == :aggregate
          rescue KeyError
            false
          end

          def infer_scope_from_argument(arg, input_metadata)
            # Use unified DimTracer for dimensional analysis
            trace_result = DimTracer.trace(arg, state)
            trace_result[:dims]
          end

          def find_deepest_input_path(expr)
            paths = collect_input_paths(expr)
            paths.max_by(&:length)
          end

          def collect_input_paths(expr)
            # Use DimTracer to collect paths instead of custom logic
            paths = []
            walk_expr(expr) do |node|
              trace = DimTracer.trace(node, state)
              if trace[:root] == :input && trace[:path]
                paths << trace[:path].split('.').map(&:to_sym) if trace[:path].is_a?(String)
              end
            end
            paths
          end
          
          def walk_expr(expr, &block)
            block.call(expr)
            case expr
            when Kumi::Syntax::CallExpression
              expr.args.each { |arg| walk_expr(arg, &block) }
            when Kumi::Syntax::ArrayExpression
              expr.elements.each { |elem| walk_expr(elem, &block) }
            when Kumi::Syntax::CascadeExpression
              expr.cases.each do |case_expr|
                walk_expr(case_expr.condition, &block)
                walk_expr(case_expr.result, &block)
              end
            end
          end

          def find_first_input_path(expr)
            return nil unless expr

            # Handle InputElementReference directly
            return expr.path if expr.is_a?(Kumi::Syntax::InputElementReference)

            # Handle InputReference (convert to path array)
            return [expr.name] if expr.is_a?(Kumi::Syntax::InputReference)

            # Recursively search in CallExpression arguments
            if expr.is_a?(Kumi::Syntax::CallExpression) && expr.args
              expr.args.each do |arg|
                path = find_first_input_path(arg)
                return path if path
              end
            end

            # Search in CascadeExpression cases
            if expr.is_a?(Kumi::Syntax::CascadeExpression) && expr.cases
              expr.cases.each do |case_item|
                path = find_first_input_path(case_item.condition)
                return path if path

                path = find_first_input_path(case_item.result)
                return path if path
              end
            end

            # Search in expression field if present
            return find_first_input_path(expr.expression) if expr.respond_to?(:expression)

            nil
          end

          # Map an input path like [:regions, :offices, :salary] to container dims [:regions, :offices]
          def dims_from_path(path, input_metadata)
            dims = []
            meta = input_metadata

            path.each do |seg|
              field = meta[seg] || meta[seg.to_sym] || meta[seg.to_s]
              break unless field

              dims << seg.to_sym if field[:type] == :array

              meta = field[:children] || {}
            end

            dims
          end

          def valid_hierarchical_broadcasting?(decl, input_metadata)
            # Simplified hierarchy check for cascades
            # Collect all input paths from the cascade and check if they can be broadcast together
            paths = collect_input_paths(decl.expression)
            return true if paths.length <= 1

            dimensions = paths.map { |path| dims_from_path(path, input_metadata) }
            return true if dimensions.length <= 1

            # Check if all dimensions form a valid hierarchy (simplified check)
            max_depth = dimensions.map(&:length).max
            dimensions.all? { |dim| dim.length <= max_depth }
          end

          def annotate_scalarized_cascade(name)
            # For now, just log that we scalarized this cascade
            puts "Scalarized cascade: #{name}" if ENV["DEBUG_SCOPE_RESOLUTION"]
            # TODO: Store this information in node_index if needed for diagnostics
          end

          def populate_node_index_scopes(node_index, final_scopes, declarations, input_metadata)
            puts "Populating node_index with inferred scopes..." if ENV["DEBUG_SCOPE_RESOLUTION"]

            # For each node in the index, infer its execution scope
            node_index.each do |object_id, entry|
              next if entry[:inferred_scope] # Skip if already set (e.g., by FunctionSignaturePass)

              inferred_scope = case entry[:type]
                               when "CallExpression"
                                 infer_call_expression_scope(entry[:node], final_scopes, declarations, input_metadata)
                               when "InputReference", "InputElementReference"
                                 infer_input_reference_scope(entry[:node], input_metadata)
                               when "DeclarationReference"
                                 infer_declaration_reference_scope(entry[:node], final_scopes)
                               when "ArrayExpression"
                                 infer_array_expression_scope(entry[:node], final_scopes, declarations, input_metadata)
                               else
                                 [] # Default to scalar scope
                               end

              entry[:inferred_scope] = Array(inferred_scope)
              
              if ENV["DEBUG_SCOPE_RESOLUTION"]
                puts "  #{entry[:type]} (#{object_id}): inferred_scope = #{entry[:inferred_scope].inspect}"
              end
            end
          end

          def infer_call_expression_scope(call_node, final_scopes, declarations, input_metadata)
            # Use DimTracer to determine the dimensional scope of this call
            trace_result = DimTracer.trace(call_node, state)
            trace_result[:dims] || []
          end

          def infer_input_reference_scope(input_node, input_metadata)
            if input_node.respond_to?(:path)
              # InputElementReference with nested path
              dims_from_path(input_node.path, input_metadata)
            elsif input_node.respond_to?(:name)
              # InputReference - check if it's an array type
              field_meta = input_metadata[input_node.name]
              field_meta && field_meta[:type] == :array ? [input_node.name.to_sym] : []
            else
              []
            end
          end

          def infer_declaration_reference_scope(decl_ref_node, final_scopes)
            # Declaration references inherit the scope of the referenced declaration
            final_scopes[decl_ref_node.name] || []
          end

          def infer_array_expression_scope(array_node, final_scopes, declarations, input_metadata)
            # Array literals typically create a new outermost dimension
            # unless all elements share a common vectorized scope
            element_scopes = array_node.elements.map do |elem|
              case elem
              when Kumi::Syntax::DeclarationReference
                final_scopes[elem.name] || []
              when Kumi::Syntax::InputElementReference
                dims_from_path(elem.path, input_metadata)
              when Kumi::Syntax::InputReference
                field_meta = input_metadata[elem.name]
                field_meta && field_meta[:type] == :array ? [elem.name.to_sym] : []
              else
                []
              end
            end

            # If all elements have the same scope, inherit it; otherwise scalar
            unique_scopes = element_scopes.uniq
            unique_scopes.length == 1 ? unique_scopes.first : []
          end
        end
      end
    end
  end
end
