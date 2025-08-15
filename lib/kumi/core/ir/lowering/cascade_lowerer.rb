# frozen_string_literal: true

module Kumi
  module Core
    module IR
      module Lowering
        # Lowers cascade expressions (if-elsif-else chains) and cascade_and conditions
        # Handles both the overall cascade structure and individual cascade_and operations
        class CascadeLowerer
          Result = Struct.new(:result_slot, :emitted)

          def initialize(shape_of:)
            @shape_of = shape_of # -> SlotShape
          end

          # Lower a cascade_and call (single condition evaluation, not boolean AND)
          # args:
          #   expr:           CallExpression node with cascade_and
          #   ops:            mutable ops array
          #   lowerer:        function that lowers sub-expressions -> lower_expression(expr, ops, ...)
          #   **opts:         options passed through to lowerer
          #
          # returns Integer - slot containing the result
          def lower_cascade_and!(expr:, ops:, lowerer:, **opts)
            # cascade_and in cascade context is just condition evaluation
            # It's not a boolean AND operation - just evaluate the condition(s)
            
            case expr.args.size
            when 1
              # Single condition - just evaluate it
              lowerer.call(expr.args.first, ops, **opts)
            when 0
              # Empty cascade_and - should be true
              ops << Kumi::Core::IR::Ops.Const(true)
              ops.size - 1
            else
              # Multiple conditions - this is actually a boolean AND chain
              # Delegate to proper boolean AND logic
              lower_multi_condition_and!(expr: expr, ops: ops, lowerer: lowerer, **opts)
            end
          end

          # Lower a full cascade expression (if-elsif-else chain)
          # args:
          #   expr:           CascadeExpression node
          #   ops:            mutable ops array
          #   lowerer:        function that lowers sub-expressions
          #   **opts:         options passed through to lowerer
          #
          # returns Integer - slot containing the result
          def lower_cascade_expression!(expr:, ops:, lowerer:, **opts)
            # Find base (true) case
            base_case = expr.cases.find { |c| c.condition.is_a?(Syntax::Literal) && c.condition.value == true }
            default_expr = base_case ? base_case.result : Kumi::Syntax::Literal.new(nil)
            branches = expr.cases.reject { |c| c.equal?(base_case) }

            # Lower each condition to determine vectorization
            precond_slots = branches.map do |c|
              lowerer.call(c.condition, ops, **opts.merge(cacheable: true))
            end
            
            precond_shapes = precond_slots.map { |s| @shape_of.call(s) }
            vec_cond_is = precond_shapes.each_index.select { |i| precond_shapes[i].kind == :vec }

            if vec_cond_is.empty?
              # Scalar cascade - use nested Select operations
              lower_scalar_cascade!(branches: branches, default_expr: default_expr, ops: ops, lowerer: lowerer, **opts)
            else
              # Vector cascade - use mask-based approach
              lower_vector_cascade!(branches: branches, default_expr: default_expr, ops: ops, lowerer: lowerer, **opts)
            end
          end

          private

          def lower_multi_condition_and!(expr:, ops:, lowerer:, **opts)
            # For multiple conditions in cascade_and, create proper AND chain
            # This should use the boolean AND logic, not cascade logic
            
            # Start with first condition
            result_slot = lowerer.call(expr.args.first, ops, **opts)
            
            # AND each subsequent condition
            expr.args[1..-1].each do |arg|
              arg_slot = lowerer.call(arg, ops, **opts)
              ops << Kumi::Core::IR::Ops.Map("core.and", 2, result_slot, arg_slot)
              result_slot = ops.size - 1
            end
            
            result_slot
          end

          def lower_scalar_cascade!(branches:, default_expr:, ops:, lowerer:, **opts)
            # Implement scalar cascade using nested Select operations
            # Works backwards from default case
            
            result_slot = lowerer.call(default_expr, ops, **opts.merge(cacheable: false))
            
            # Process branches in reverse order to build nested structure
            branches.reverse.each do |branch|
              condition_slot = lowerer.call(branch.condition, ops, **opts.merge(cacheable: false))
              branch_result_slot = lowerer.call(branch.result, ops, **opts.merge(cacheable: false))
              
              # Select(condition, branch_result, current_result)
              ops << Kumi::Core::IR::Ops.Select(condition_slot, branch_result_slot, result_slot)
              result_slot = ops.size - 1
            end
            
            result_slot
          end

          def lower_vector_cascade!(branches:, default_expr:, ops:, lowerer:, **opts)
            # Implement vector cascade using mask-based approach
            # TODO: This is more complex and may need the existing cascade lowering logic
            # For now, fall back to the scalar approach
            lower_scalar_cascade!(branches: branches, default_expr: default_expr, ops: ops, lowerer: lowerer, **opts)
          end
        end
      end
    end
  end
end