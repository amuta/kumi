# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Plans join and reduce operations for declarations.
        # Determines reduction axes, flattening requirements, and join policies.
        # Also stores join plans in node_index for LowerToIRPass compatibility.
        #
        # DEPENDENCIES: :broadcasts, :scope_plans, :decl_shapes, :declarations, :input_metadata, :node_index
        # PRODUCES: :join_reduce_plans, updates :node_index with join plans
        class JoinReducePlanningPass < PassBase
          include Kumi::Core::Analyzer::Plans

          def run(_errors)
            node_index = get_state(:node_index, required: true)
            broadcasts = get_state(:broadcasts, required: false) || {}
            scope_plans = get_state(:scope_plans, required: false) || {}
            declarations = get_state(:declarations, required: true)
            input_metadata = get_state(:input_metadata, required: true)

            plans = {}

            # Process reduction operations
            process_reductions(broadcasts, scope_plans, declarations, input_metadata, plans, node_index)

            # Process join operations (for non-reduction vectorized operations)
            process_joins(broadcasts, scope_plans, declarations, plans, node_index)

            # Process all remaining CallExpression nodes that don't have join plans yet
            process_remaining_calls(node_index, scope_plans, declarations, input_metadata)

            # Return new state with join/reduce plans and updated node_index
            state.with(:join_reduce_plans, plans.freeze)
                 .with(:node_index, node_index)
          end

          def each_call(expr, &blk)
            return unless expr
            stack = [expr]
            while (n = stack.pop)
              blk.call(n) if n.is_a?(Kumi::Syntax::CallExpression)
              n.children.each { |c| stack << c if c.respond_to?(:children) }
            end
          end

          private

          def process_reductions(broadcasts, scope_plans, declarations, input_metadata, plans, node_index)
            reduction_ops = broadcasts[:reduction_operations] || {}

            reduction_ops.each do |name, info|
              debug_reduction(name, info) if ENV["DEBUG_JOIN_REDUCE"]

              # Get the source scope from scope_plans or infer from argument
              source_scope = get_source_scope(name, info, scope_plans, declarations, input_metadata)

              # Determine reduction axis and result scope
              axis, result_scope = determine_reduction_axis(source_scope, info, scope_plans, name)

              # Check for flattening requirements
              flatten_indices = determine_flatten_indices(info)

              plan = Reduce.new(
                function: info[:function],
                axis: axis,
                source_scope: source_scope,
                result_scope: result_scope,
                flatten_args: flatten_indices
              )

              plans[name] = plan

              # Attach to the actual reducer call in the decl
              decl = declarations[name] or next
              each_call(decl.expression) do |call|
                next unless call.fn_name == info[:function] || call.effective_fn_name == info[:function]
                arg_dims = arg_dims_list(call, node_index)
                lifts = compute_lifts(arg_dims, source_scope)  # align arg to source_scope for reduce
                node_index[call.object_id] ||= {}
                node_index[call.object_id][:join_plan] = {
                  policy: :reduce,
                  target_scope: result_scope,
                  axis: axis,
                  flatten_args: Array(flatten_indices),
                  lifts: lifts,
                  requires_indices: compute_requires_indices(arg_dims, source_scope, is_reduce: true)
                }
                break
              end

              debug_reduction_plan(name, plan) if ENV["DEBUG_JOIN_REDUCE"]
            end
          end

          def process_joins(broadcasts, scope_plans, declarations, plans, node_index)
            vectorized_ops = broadcasts[:vectorized_operations] || {}

            vectorized_ops.each do |name, _info|
              next if plans.key?(name)
              scope_plan = scope_plans[name] or next
              decl = declarations[name] or next

              # annotate per-call
              each_call(decl.expression) do |call|
                arg_dims = arg_dims_list(call, node_index)
                tgt = Array(scope_plan.scope)
                policy = resolve_policy(call) # defaults to :zip unless registry says otherwise
                lifts = compute_lifts(arg_dims, tgt)
                node_index[call.object_id] ||= {}
                node_index[call.object_id][:join_plan] = {
                  policy: policy,
                  target_scope: tgt,
                  lifts: lifts,
                  requires_indices: compute_requires_indices(arg_dims, tgt, is_reduce: false)
                }
              end
            end

            # Process scalar declarations that need broadcasting to vectorized scopes
            # (These are referenced by vectorized cascades but aren't vectorized themselves)
            scope_plans.each do |name, scope_plan|
              # Skip if already processed
              next if plans.key?(name)
              
              # Skip if no vectorized target scope
              next unless scope_plan.scope && !scope_plan.scope.empty?
              
              # Skip if already vectorized (handled above)
              next if vectorized_ops.key?(name)
              
              # Check if this scalar declaration needs broadcasting
              if needs_scalar_to_vector_broadcast?(name, scope_plan, declarations, vectorized_ops)
                debug_scalar_broadcast(name, scope_plan) if ENV["DEBUG_JOIN_REDUCE"]
                
                plan = Join.new(
                  policy: :broadcast, # Use broadcast policy for scalar-to-vector
                  target_scope: scope_plan.scope
                )

                plans[name] = plan

                # Also store in node_index for LowerToIRPass compatibility
                store_join_plan_in_node_index(name, plan, declarations, node_index)

                debug_join_plan(name, plan) if ENV["DEBUG_JOIN_REDUCE"]
              end
            end
          end

          def get_source_scope(name, reduction_info, scope_plans, declarations, input_metadata)
            # Always infer from the reduction argument - this is the full dimensional scope
            infer_scope_from_argument(reduction_info[:argument], declarations, input_metadata)
          end

          def determine_reduction_axis(source_scope, reduction_info, scope_plans, name)
            return [[], []] if source_scope.empty?

            # Check if explicit axis is specified
            if reduction_info[:axis]
              axis = reduction_info[:axis]
              result_scope = compute_result_scope(source_scope, axis)
              return [axis, result_scope]
            end

            # Check if there's a scope plan that specifies what to preserve (result_scope)
            scope_plan = scope_plans[name]
            if scope_plan&.scope && !scope_plan.scope.empty?
              desired_result_scope = scope_plan.scope
              # Compute axis by removing the desired result dimensions
              axis = source_scope - desired_result_scope
              return [axis, desired_result_scope]
            end

            # Default: reduce innermost dimension (partial reduction)
            axis = [source_scope.last]
            result_scope = source_scope[0...-1]

            [axis, result_scope]
          end

          def compute_result_scope(source_scope, axis)
            # Remove specified axis dimensions from source scope
            case axis
            when :all
              []
            when Array
              source_scope - axis
            when Integer
              # Numeric axis: remove that many innermost dimensions
              source_scope[0...-axis]
            else
              source_scope
            end
          end

          def determine_flatten_indices(reduction_info)
            # Check for explicit flatten requirements
            flatten = reduction_info[:flatten_argument_indices] || []
            Array(flatten)
          end

          def requires_join?(declaration, scope_plan)
            return false unless declaration
            return false unless scope_plan.scope && !scope_plan.scope.empty?

            expr = declaration.expression

            case expr
            when Kumi::Syntax::CallExpression
              # Multiple arguments suggest potential join requirement
              expr.args.size > 1
            when Kumi::Syntax::CascadeExpression
              # Cascades with vectorized target scope need join planning
              # to handle cross-scope conditions and results
              true
            else
              false
            end
          end

          def infer_scope_from_argument(arg, declarations, input_metadata)
            return [] unless arg

            case arg
            when Kumi::Syntax::InputElementReference
              # Extract scope from the input path
              path = arg.path
              return [] if path.empty?
              
              # Remove the leaf field to get the array path
              array_path = path[0...-1]
              return [] if array_path.empty?
              
              array_path
            when Kumi::Syntax::DeclarationReference
              # Follow declaration reference to its source
              decl = declarations[arg.name]
              return [] unless decl
              
              infer_scope_from_argument(decl.expression, declarations, input_metadata)
            else
              []
            end
          end

          def needs_scalar_to_vector_broadcast?(name, scope_plan, declarations, vectorized_ops)
            # Check if this scalar declaration is referenced by any vectorized operation
            # that requires it to be broadcast to a vectorized scope
            
            # Look for vectorized operations that reference this declaration
            vectorized_ops.each do |vec_name, vec_info|
              vec_decl = declarations[vec_name]
              next unless vec_decl
              
              # Check if this vectorized operation references our scalar declaration
              if declaration_references?(vec_decl.expression, name)
                return true
              end
            end
            
            false
          end

          def declaration_references?(expr, target_name)
            case expr
            when Kumi::Syntax::DeclarationReference
              expr.name == target_name
            when Kumi::Syntax::CallExpression
              expr.args.any? { |arg| declaration_references?(arg, target_name) }
            when Kumi::Syntax::CascadeExpression
              expr.cases.any? do |case_expr|
                declaration_references?(case_expr.condition, target_name) ||
                declaration_references?(case_expr.result, target_name)
              end
            when Kumi::Syntax::ArrayExpression
              expr.elements.any? { |elem| declaration_references?(elem, target_name) }
            else
              false
            end
          end

          # === helpers used above ===
          def arg_dims_list(call, node_index)
            call.args.map { |a| (node_index[a.object_id] || {})[:inferred_scope] || [] }
          end

          def resolve_policy(call)
            entry = Kumi::Registry.entry(call.fn_name) rescue nil
            entry = Kumi::Registry.entry(call.effective_fn_name) rescue nil if !entry
            (entry && entry.zip_policy) || :zip
          end

          def compute_lifts(arg_dims_list, target_scope)
            td = Array(target_scope).size
            arg_dims_list.map do |dims|
              need = td - Array(dims).size
              need <= 0 ? [] : Array.new(need, :lift)
            end
          end

          def compute_requires_indices(arg_dims_list, target_scope, is_reduce:)
            td = Array(target_scope).size
            arg_dims_list.map do |dims|
              d = Array(dims).size
              is_reduce ? (d > 0) : (d < td) || (d > 0) # if we need to lift/broadcast or carry rows, prefer indexed
            end
          end

          def process_remaining_calls(node_index, scope_plans, declarations, input_metadata)
            if ENV["DEBUG_JOIN_REDUCE"]
              puts "\n=== Processing remaining CallExpression nodes ==="
            end

            # Find all CallExpression nodes that don't have join plans yet
            node_index.each do |object_id, entry|
              next unless entry[:type] == "CallExpression"
              next if entry[:join_plan] # Skip if already has a join plan

              call = entry[:node]
              if ENV["DEBUG_JOIN_REDUCE"]
                puts "Processing remaining call: #{call.fn_name} (#{object_id})"
              end

              # Create a basic scalar join plan for this call
              # Most scalar operations will use this
              arg_dims = arg_dims_list(call, node_index)
              lifts = [] # No lifts needed for scalar operations
              
              entry[:join_plan] = {
                policy: :zip, # Default policy for scalar operations
                target_scope: [], # Scalar result
                axis: [],
                flatten_args: [],
                lifts: lifts,
                requires_indices: Array.new(arg_dims.length, false)
              }

              if ENV["DEBUG_JOIN_REDUCE"]
                puts "  Added scalar join plan: #{entry[:join_plan].inspect}"
              end
            end
          end

          def store_join_plan_in_node_index(name, plan, declarations, node_index)
            # Find the expression that needs the join plan
            declaration = declarations[name]
            return unless declaration

            expr = declaration.expression
            return unless expr

            # Store the join plan in node_index for LowerToIRPass to find
            node_index[expr.object_id] ||= {}
            
            case plan
            when Join
              node_index[expr.object_id][:join_plan] = {
                policy: plan.policy,
                target_scope: plan.target_scope,
                lifts: [] # LowerToIRPass will compute specific lifts as needed
              }
            when Reduce
              # For reduction plans, create a simplified join plan that LowerToIRPass can use
              node_index[expr.object_id][:join_plan] = {
                policy: :reduce,
                target_scope: plan.result_scope,
                axis: plan.axis,
                lifts: []
              }
            end
          end

          # Debug helpers
          def debug_reduction(name, info)
            puts "\n=== Processing reduction: #{name} ==="
            puts "Function: #{info[:function]}"
            puts "Argument: #{info[:argument].class}"
          end

          def debug_reduction_plan(name, plan)
            puts "Reduction plan for #{name}:"
            puts "  Axis: #{plan.axis.inspect}"
            puts "  Source scope: #{plan.source_scope.inspect}"
            puts "  Result scope: #{plan.result_scope.inspect}"
          end

          def debug_join(name, info)
            puts "\n=== Processing join: #{name} ==="
            puts "Source: #{info[:source]}"
          end

          def debug_join_plan(name, plan)
            puts "Join plan for #{name}:"
            puts "  Target scope: #{plan.target_scope.inspect}"
            puts "  Policy: #{plan.policy}"
          end

          def debug_scalar_broadcast(name, scope_plan)
            puts "\n=== Processing scalar broadcast: #{name} ==="
            puts "Target scope: #{scope_plan.scope.inspect}"
          end
        end
      end
    end
  end
end
