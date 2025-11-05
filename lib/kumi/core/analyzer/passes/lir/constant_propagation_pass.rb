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
                operations = Array(payload[:operations])
                out[name] = { operations: optimize_decl(operations) }
              end

              out.freeze
              state.with(:lir_module, out).with(:lir_06_const_prop, out)
            end

            private

            def optimize_decl(ops)
              rewritten = ops.map(&:dup)
              use_counts = Hash.new(0)

              rewritten.each do |ins|
                Array(ins.inputs).each do |reg|
                  use_counts[reg] += 1 if reg
                end
              end

              constants = {}

              LIR::Peephole.run(rewritten) do |window|
                ins = window.current
                break unless ins

                substitution = substitute_inputs(ins, constants)

                if substitution
                  new_ins, replaced_regs = substitution
                  window.replace(1, with: new_ins)
                  replaced_regs.each do |reg|
                    use_counts[reg] -= 1
                  end
                end

                register = window.result_register
                constants.delete(register) if register

                if register && window.const?
                  literal = window.literal
                  constants[register] = literal if literal
                end

                window.skip
              end

              rewritten.reject! do |ins|
                reg = ins.result_register
                ins.opcode == :Constant && reg && use_counts[reg].zero?
              end

              rewritten
            end

            def substitute_inputs(ins, constants)
              original_inputs = Array(ins.inputs)
              original_imms   = Array(ins.immediates)

              new_inputs = []
              new_imms   = []
              changed    = false
              replaced_regs = []

              original_inputs.each do |reg|
                if (literal = constants[reg])
                  new_inputs << :__immediate_placeholder__
                  new_imms << literal
                  changed = true
                  replaced_regs << reg
                else
                  new_inputs << reg
                end
              end

              new_imms.concat(original_imms)
              changed ||= new_imms != original_imms

              return unless changed

              instruction = LIR::Instruction.new(
                opcode: ins.opcode,
                result_register: ins.result_register,
                stamp: ins.stamp,
                inputs: new_inputs.empty? ? [] : new_inputs,
                immediates: new_imms.empty? ? [] : new_imms,
                attributes: ins.attributes,
                location: ins.location
              )
              [instruction, replaced_regs]
            end
          end
        end
      end
    end
  end
end
