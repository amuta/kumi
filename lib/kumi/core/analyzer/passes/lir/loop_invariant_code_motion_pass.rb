# frozen_string_literal: true

require "set"

module Kumi
  module Core
    module Analyzer
      module Passes
        module LIR
          # LoopInvariantCodeMotionPass (LICM)
          # ---------------------------------
          # Identifies and hoists loop-invariant code out of loops. This pass
          # significantly improves performance by preventing redundant calculations
          # inside loops.
          #
          # An instruction is loop-invariant if it's pure (no side effects) and
          # all of its inputs are defined outside the current loop.
          #
          # The pass runs iteratively until no more code can be hoisted, ensuring
          # that hoisting one instruction can enable others to be hoisted in a
          # subsequent pass.
          #
          # In : state[:lir_module]
          # Out: state.with(:lir_module, ...)
          class LoopInvariantCodeMotionPass < PassBase
            LIR = Kumi::Core::LIR
            MAX_PASSES = 10 # A safeguard against infinite loops

            def run(_errors)
              current_ops = get_state(:lir_module)

              MAX_PASSES.times do
                new_ops, changed = run_one_pass(current_ops)
                return state.with(:lir_module, new_ops.freeze).with(:lir_04_loop_invcm, new_ops) unless changed

                current_ops = new_ops
              end

              raise "LICM did not converge after #{MAX_PASSES} passes."
            end

            private

            def run_one_pass(ops_by_decl)
              changed = false
              new_ops_by_decl = {}

              ops_by_decl.each do |name, payload|
                original_ops = Array(payload[:operations])
                optimized_ops = optimize_decl(original_ops)
                new_ops_by_decl[name] = { operations: optimized_ops }
                changed ||= (original_ops != optimized_ops)
              end

              [new_ops_by_decl, changed]
            end

            def optimize_decl(ops)
              hoist_in_block(ops)
            end

            def hoist_in_block(ops)
              new_ops = []
              i = 0
              while i < ops.length
                ins = ops[i]

                if ins.opcode == :LoopStart
                  end_index = find_matching_loop_end(ops, i)
                  loop_body = ops[(i + 1)...end_index]
                  optimized_body = hoist_in_block(loop_body)
                  defs_in_loop = get_defs_in_ops(optimized_body)

                  # --- FIX ---
                  # Also consider the loop's own element and index registers as loop-variant.
                  loop_element_reg = ins.attributes[:as_element]
                  loop_index_reg = ins.attributes[:as_index]
                  defs_in_loop.add(loop_element_reg) if loop_element_reg
                  defs_in_loop.add(loop_index_reg) if loop_index_reg
                  # --- END OF FIX ---

                  invariant_ops, variant_ops = optimized_body.partition do |body_ins|
                    is_invariant(body_ins, defs_in_loop)
                  end

                  new_ops.concat(invariant_ops)
                  new_ops << ins
                  new_ops.concat(variant_ops)
                  new_ops << ops[end_index]

                  i = end_index + 1
                else
                  new_ops << ins
                  i += 1
                end
              end
              new_ops
            end

            def is_invariant(ins, defs_in_loop)
              return false unless ins.pure?

              (Set.new(Array(ins.inputs)) & defs_in_loop).empty?
            end

            def get_defs_in_ops(ops)
              defs = Set.new
              ops.each do |ins|
                defs.add(ins.result_register) if ins.result_register
                if ins.opcode == :LoopStart
                  defs.add(ins.attributes[:as_element])
                  defs.add(ins.attributes[:as_index])
                end
              end
              defs
            end

            def find_matching_loop_end(ops, start_index)
              depth = 1
              (start_index + 1).upto(ops.length - 1) do |i|
                opcode = ops[i].opcode
                depth += 1 if opcode == :LoopStart
                depth -= 1 if opcode == :LoopEnd
                return i if depth.zero?
              end
              raise "Unbalanced LoopStart at index #{start_index}"
            end
          end
        end
      end
    end
  end
end
