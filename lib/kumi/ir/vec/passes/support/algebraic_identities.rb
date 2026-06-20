# frozen_string_literal: true

module Kumi
  module IR
    module Vec
      module Passes
        module Support
          # Algebraic identities that reduce a binary `map` (`a OP b`) to one of
          # its operands. Applied ONLY when it is exact for the dtype under IEEE
          # 754 and keeps the result dtype/axes (so no promotion is dropped):
          #
          #   x * 1, 1 * x, x / 1, x - 0   safe for every numeric dtype
          #   x + 0, 0 + x, x * 0, 0 * x   integer only
          #     (float x + 0.0 drops a -0.0 sign; float x * 0.0 is NaN when x is
          #      Infinity/NaN — both would change the result)
          #
          # Pure: given the rewritten operand registers, their known constant
          # values, and a reg=>instruction table for dtype/axes, it returns the
          # surviving register or nil. The caller drops the map and rewrites uses.
          module AlgebraicIdentities
            module_function

            def survivor(instr, inputs, constants, defs)
              return nil unless inputs.size == 2

              left, right = inputs
              left_const = constants[left]
              right_const = constants[right]
              integer = numeric_kind(instr.dtype) == :integer

              case instr.attributes[:fn]
              when :"core.mul:numeric"
                return keep(right, instr, defs) if one?(left_const)              # 1 * x
                return keep(left, instr, defs)  if one?(right_const)             # x * 1
                return keep(left, instr, defs)  if integer && zero?(left_const)  # 0 * x -> zero
                return keep(right, instr, defs) if integer && zero?(right_const) # x * 0 -> zero
              when :"core.div"
                return keep(left, instr, defs) if one?(right_const) # x / 1
              when :"core.add"
                return keep(right, instr, defs) if integer && zero?(left_const)  # 0 + x
                return keep(left, instr, defs)  if integer && zero?(right_const) # x + 0
              when :"core.sub"
                return keep(left, instr, defs) if zero?(right_const) # x - 0
              end
              nil
            end

            # The surviving operand replaces the map only when it carries the
            # same dtype (never erase a promotion) and the same axes.
            def keep(reg, instr, defs)
              src = defs[reg]
              return nil unless src
              return nil unless numeric_kind(src.dtype) == numeric_kind(instr.dtype)
              return nil unless Array(src.axes) == Array(instr.axes)

              reg
            end

            def one?(value)  = [1, 1.0].include?(value)
            def zero?(value) = [0, 0.0].include?(value)

            def numeric_kind(dtype)
              dtype.respond_to?(:kind) ? dtype.kind : dtype
            end
          end
        end
      end
    end
  end
end
