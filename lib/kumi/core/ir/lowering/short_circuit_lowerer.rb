# frozen_string_literal: true

module Kumi
  module Core
    module IR
      module Lowering
        # Lowers boolean operations with short_circuit traits to guard-based lazy evaluation
        # Uses traits from RegistryV2 to determine annihilator values and generate Select ops
        class ShortCircuitLowerer
          Result = Struct.new(:op_index, :result_slot, :emitted)

          def initialize(shape_of:, registry:)
            @shape_of = shape_of # -> SlotShape  
            @registry = registry # RegistryV2 instance
          end

          # Lower a short-circuit boolean operation with proper guard-based evaluation
          # This method handles the complete lowering of the expression, including argument lowering
          # args:
          #   expr:           CallExpression node with 2 arguments
          #   ops:            mutable ops array  
          #   lowerer:        function that lowers sub-expressions -> lower_expression(expr, ops, ...)
          #   **opts:         options passed through to lowerer
          #
          # returns Integer - slot containing the result
          def lower_expression!(expr:, ops:, lowerer:, **opts)
            raise ArgumentError, "Expected exactly 2 arguments for short-circuit operation" unless expr.args.size == 2
            
            lhs_arg, rhs_arg = expr.args
            fn_name = get_qualified_name(expr, opts)
            annihilator = get_annihilator_value(fn_name)
            
            # Lower LHS first
            lhs_slot = lowerer.call(lhs_arg, ops, **opts)
            
            # Compute guard from algebra.annihilator:
            # OR (annihilator: true): guard = not(L) - only evaluate RHS where L is false  
            # AND (annihilator: false): guard = L - only evaluate RHS where L is true
            guard_slot = if annihilator == true
              # OR: guard = not(L)
              ops << Kumi::Core::IR::Ops.Map("core.not", 1, lhs_slot)
              ops.size - 1
            else
              # AND: guard = L
              lhs_slot
            end
            
            # GuardPush(guard); lower RHS → R_guarded; GuardPop
            ops << Kumi::Core::IR::Ops.GuardPush(guard_slot)
            rhs_slot = lowerer.call(rhs_arg, ops, **opts.merge(cacheable: false))
            ops << Kumi::Core::IR::Ops.GuardPop
            
            # Emit Select based on operation type:
            # OR -> Select(L, true, R_guarded)
            # AND -> Select(L, R_guarded, false)
            if annihilator == true
              # OR
              true_slot = ops.size
              ops << Kumi::Core::IR::Ops.Const(true)
              ops << Kumi::Core::IR::Ops.Select(lhs_slot, true_slot, rhs_slot)
            else
              # AND  
              false_slot = ops.size
              ops << Kumi::Core::IR::Ops.Const(false)
              ops << Kumi::Core::IR::Ops.Select(lhs_slot, rhs_slot, false_slot)
            end
            
            ops.size - 1
          end

          # Lower pre-computed argument slots (legacy interface)
          def lower!(ops:, fn_name:, arg_slots:, result_slot:)
            raise ArgumentError, "Expected exactly 2 arguments for short-circuit operation" unless arg_slots.length == 2
            
            left_slot, right_slot = arg_slots
            annihilator = get_annihilator_value(fn_name)

            # For pre-computed slots, we can't do lazy evaluation, just use Select directly
            if annihilator == true
              # OR: Select(left, true, right)
              ops << Kumi::Core::IR::Ops.Const(true)
              true_slot = ops.size - 1
              ops << Kumi::Core::IR::Ops.Select(left_slot, true_slot, right_slot)
            else
              # AND: Select(left, right, false)
              ops << Kumi::Core::IR::Ops.Const(false)
              false_slot = ops.size - 1
              ops << Kumi::Core::IR::Ops.Select(left_slot, right_slot, false_slot)
            end

            Result.new(ops.size - 1, ops.size - 1, [ops.size - 1])
          end

          # Check if a function has short_circuit trait
          def short_circuit?(fn_name)
            begin
              func = @registry.fetch(fn_name)
              vectorization = func.vectorization || {}
              vectorization[:short_circuit] == 'left_to_right'
            rescue
              false
            end
          end

          private

          def get_qualified_name(expr, opts)
            # Extract qualified name from expression context
            # This should be provided by the caller
            opts[:qualified_fn_name] || "core.#{expr.fn_name}"
          end

          def get_annihilator_value(fn_name)
            begin
              func = @registry.fetch(fn_name)
              algebra = func.algebra || {}
              algebra[:annihilator]
            rescue => e
              raise "Cannot determine annihilator for #{fn_name}: #{e.message}"
            end
          end
        end
      end
    end
  end
end