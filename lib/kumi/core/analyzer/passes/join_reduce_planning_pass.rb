# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Plans join and reduce operations for declarations.
        # Determines reduction axes, flattening requirements, and join policies.
        #
        # DEPENDENCIES: :broadcasts, :scope_plans, :decl_shapes, :declarations, :input_metadata
        # PRODUCES: :join_reduce_plans
        class JoinReducePlanningPass < PassBase
          include Kumi::Core::Analyzer::Plans

          def run(_errors)
            broadcasts = get_state(:broadcasts, required: false) || {}
            scope_plans = get_state(:scope_plans, required: false) || {}
            declarations = get_state(:declarations, required: true)
            input_metadata = get_state(:input_metadata, required: true)

            plans = {}

            # Process reduction operations
            process_reductions(broadcasts, scope_plans, declarations, input_metadata, plans)

            # Process join operations (for non-reduction vectorized operations)
            process_joins(broadcasts, scope_plans, declarations, plans)

            # Return new state with join/reduce plans
            state.with(:join_reduce_plans, plans.freeze)
          end

          private

          def process_reductions(broadcasts, scope_plans, declarations, input_metadata, plans)
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

              debug_reduction_plan(name, plan) if ENV["DEBUG_JOIN_REDUCE"]
            end
          end

          def process_joins(broadcasts, scope_plans, declarations, plans)
            vectorized_ops = broadcasts[:vectorized_operations] || {}

            vectorized_ops.each do |name, info|
              # Skip if already processed as reduction
              next if plans.key?(name)

              debug_join(name, info) if ENV["DEBUG_JOIN_REDUCE"]

              scope_plan = scope_plans[name]
              next unless scope_plan

              # Only need join planning if multiple arguments at different scopes
              next unless requires_join?(declarations[name], scope_plan)

              plan = Join.new(
                policy: :zip, # Default to zip for array operations
                target_scope: scope_plan.scope
              )

              plans[name] = plan

              debug_join_plan(name, plan) if ENV["DEBUG_JOIN_REDUCE"]
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

            # Check if expression has multiple arguments that could be at different scopes
            expr = declaration.expression
            return false unless expr.is_a?(Kumi::Syntax::CallExpression)

            # Multiple arguments suggest potential join requirement
            expr.args.size > 1
          end

          def infer_scope_from_argument(arg, declarations, input_metadata)
            return [] unless arg

            case arg
            when Kumi::Syntax::InputElementReference
              dims_from_path(arg.path, input_metadata)
            when Kumi::Syntax::DeclarationReference
              # Look up the declaration's scope if available
              decl = declarations[arg.name]
              decl ? infer_scope_from_argument(decl.expression, declarations, input_metadata) : []
            when Kumi::Syntax::CallExpression
              # For calls, use the deepest scope from arguments
              scopes = arg.args.map { |a| infer_scope_from_argument(a, declarations, input_metadata) }
              scopes.max_by(&:size) || []
            else
              []
            end
          end

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
        end
      end
    end
  end
end
