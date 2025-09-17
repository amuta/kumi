# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module LIR
          # ConstantPropagationPass
          # --------------------------
          # This is an intra-block constant propagation pass. It substitutes the
          # uses of registers that hold a known constant value with the literal
          # constant itself.
          #
          # This pass must run before DeadCodeEliminationPass to be effective. It
          # doesn't remove the original constant assignments; rather, it makes
          # them "dead" by removing their uses, allowing a subsequent DCE pass
          # to clean them up.
          #
          # In : state[:lir_module]
          # Out: state.with(:lir_02_const_prop, ...)
          class ConstantPropagationPass < PassBase
            LIR = Kumi::Core::LIR

            def run(_errors)
              ops_by_decl = get_state(:lir_module)
              out = {}

              ops_by_decl.each do |name, payload|
                out[name] = { operations: optimize_decl(Array(payload[:operations])) }
              end

              out.freeze
              state.with(:lir_06_const_prop, out).with(:lir_module, out.freeze)
            end

            private

            def optimize_decl(ops)
              known_constants = {}
              new_ops = []

              ops.each do |ins|
                # --- START OF THE FIX ---

                new_inputs = []
                new_immediates = []

                # Process inputs, replacing known constants with a placeholder.
                Array(ins.inputs).each do |input_reg|
                  if (literal = known_constants[input_reg])
                    new_inputs << :__immediate_placeholder__
                    new_immediates << literal
                  else
                    new_inputs << input_reg
                  end
                end

                # Append any existing immediates after the new ones.
                new_immediates.concat(Array(ins.immediates))

                modified_ins = ins.dup
                modified_ins.inputs = new_inputs
                modified_ins.immediates = new_immediates
                new_ops << modified_ins

                # --- END OF THE FIX ---

                # Update the map based on the MODIFIED instruction.
                known_constants.delete(modified_ins.result_register) if modified_ins.result_register
                if modified_ins.opcode == :Constant && modified_ins.immediates&.first
                  known_constants[modified_ins.result_register] = modified_ins.immediates.first
                end
              end

              new_ops
            end
          end
        end
      end
    end
  end
end
