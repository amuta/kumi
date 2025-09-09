# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module LIR
          # DeadCodeEliminationPass
          # --------------------------
          # Removes instructions whose results are never used. This is a critical
          # cleanup pass that runs after other optimizations (like CSE), which often
          # leave behind unused variable assignments.
          #
          # The algorithm works by performing a backward pass over the instructions
          # of a declaration, tracking the set of "live" registers at each point.
          # A register is considered "live" if its value is needed by a future
          # instruction that has an observable effect on the program's output.
          #
          # In : state[:lir_03_cse] (or from fused/initial LIR)
          # Out: state.with(:lir_03_cse, ...)
          class DeadCodeEliminationPass < PassBase
            LIR = Kumi::Core::LIR

            def run(_errors)
              # This pass can run on the output of CSE, fusion, or the initial LIR.
              ops_by_decl =
                get_state(:lir_03_cse, required: false)

              out = {}
              ops_by_decl.each do |name, payload|
                out[name] = { operations: optimize_decl(Array(payload[:operations])) }
              end

              out.freeze

              # Overwrite the :lir_03_cse state with the cleaned-up version.
              state.with(:lir_module, out).with(:lir_03_cse, out)
            end

            private

            # This is the core of the DCE algorithm for a single declaration.
            # It iterates backward from the last instruction to the first.
            def optimize_decl(ops)
              # An instruction is considered "live" (i.e., it must be kept) if either:
              # 1. It has a side effect.
              # 2. Its result is used by another live instruction down the line.
              live = Set.new
              new_ops = []

              ops.reverse_each do |ins|
                is_live = ins.side_effect? || (ins.result_register && live.include?(ins.result_register))

                # If the instruction is live, we must keep it.
                next unless is_live

                new_ops.unshift(ins)
                # Update the live set based on this instruction's needs:
                # 1. The register this instruction *defines* is no longer needed
                #    from any *earlier* instruction, so we remove it from the live set.
                live.delete(ins.result_register) if ins.result_register

                # 2. The registers this instruction *uses* must have been defined
                #    by earlier instructions, so we add them to the live set.
                Array(ins.inputs).each { |input| live.add(input) if input }
                # If an instruction is not live, we do nothing. It is effectively
                # dropped from the final list of operations.
              end
              new_ops
            end
          end
        end
      end
    end
  end
end
