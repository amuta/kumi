# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module LIR
          # LoopFusionPass (Simplified Version)
          # --------------
          #
          # This pass runs AFTER InlineDeclarationsPass AND LocalCSEPass.
          # The CSE pass is crucial as it normalizes the LIR, ensuring that any
          # redundant collection loads are eliminated. This simplifies loop fusion
          # from a data-flow analysis problem to a simple check for adjacent loops
          # iterating over the *exact same register*.
          #
          # A loop pair is considered "fusable" if:
          #   1. They are "semantically adjacent," meaning they are separated only by
          #      instructions that can be correctly reordered around the fused loop
          #      (e.g., DeclareAccumulator, LoadAccumulator).
          #   2. They iterate over the identical collection register.
          #
          class LoopFusionPass < PassBase
            LIR = Kumi::Core::LIR
            def run(_errors)
              fused_module = get_state(:lir_module).transform_values do |decl|
                # The decl[:name] might not exist in older states, so provide a fallback.
                decl_name = decl.is_a?(Hash) ? decl.fetch(:name, "anonymous") : "anonymous"
                debug "\n--- Fusing loops in: #{decl_name} ---"
                { operations: fuse_loops_in_block(Array(decl[:operations])) }
              end

              state.with(:lir_module, fused_module).with(:lir_04_1_loop_fusion, fused_module)
            end

            private

            def fuse_loops_in_block(ops)
              changed = true
              current_ops = ops
              current_ops, changed = run_one_fusion_pass(current_ops) while changed
              current_ops
            end

            def run_one_fusion_pass(ops)
              new_ops = []
              changed = false
              i = 0

              while i < ops.length
                ins1 = ops[i]

                if ins1.opcode == :LoopStart
                  debug "  > Found LoopStart(#{ins1.attributes[:id]}) at index #{i} over register #{ins1.inputs.first}"
                  end1_idx = find_matching_loop_end(ops, i)

                  # NEW: Intelligently scan and classify instructions between loops.
                  pre_fusion_ops, post_fusion_ops, next_ins_idx = scan_and_classify_intervening_ops(ops, end1_idx)

                  if next_ins_idx
                    ins2 = ops[next_ins_idx]
                    debug "    - Found next candidate LoopStart(#{ins2.attributes[:id]}) at index #{next_ins_idx}"

                    # CONDITION: Loop collections must be the IDENTICAL register (thanks to CSE).
                    are_collections_identical = ins1.inputs.first == ins2.inputs.first
                    debug "    - Checking collections '#{ins1.inputs.first}' vs '#{ins2.inputs.first}'... Identical? #{are_collections_identical}"

                    if are_collections_identical
                      changed = true
                      debug "    - SUCCESS: Fusing loops #{ins1.attributes[:id]} and #{ins2.attributes[:id]}."

                      body1 = ops[(i + 1)...end1_idx]
                      end2_idx = find_matching_loop_end(ops, next_ins_idx)
                      body2 = ops[(next_ins_idx + 1)...end2_idx]

                      remap = {
                        ins2.attributes[:as_element] => ins1.attributes[:as_element],
                        ins2.attributes[:as_index] => ins1.attributes[:as_index]
                      }
                      remapped_body2 = remap_registers(body2, remap)
                      fused_body = fuse_loops_in_block(body1 + remapped_body2)

                      # Correctly re-order the intervening instructions around the fused loop.
                      new_ops.concat(pre_fusion_ops) # Declarations for loop 2 go before.
                      new_ops << ins1
                      new_ops.concat(fused_body)
                      new_ops << ops[end1_idx]
                      new_ops.concat(post_fusion_ops) # Loads from loop 1 go after.

                      i = end2_idx + 1
                      next
                    else
                      debug "    - INFO: Collections not identical. No fusion."
                    end
                  end
                end

                new_ops << ins1
                i += 1
              end

              [new_ops, changed]
            end

            # --- NEW: Replaced dumb scan with intelligent classification ---
            # Scans between loops and classifies instructions into two buckets:
            # - pre_ops: Ops that must execute before the fused loop (e.g., DeclareAccumulator for loop 2)
            # - post_ops: Ops that must execute after the fused loop (e.g., LoadAccumulator from loop 1)
            # If any unmovable instruction is found, it aborts.
            def scan_and_classify_intervening_ops(ops, start_idx)
              pre_ops = []
              post_ops = []
              (start_idx + 1...ops.length).each do |i|
                ins = ops[i]
                case ins.opcode
                when :LoopStart
                  return [pre_ops, post_ops, i]
                when :DeclareAccumulator
                  pre_ops << ins
                when :LoadAccumulator
                  post_ops << ins
                else
                  # Found an unmovable instruction; fusion is not possible.
                  return [[], [], nil]
                end
              end
              [[], [], nil] # No next loop found
            end

            def find_matching_loop_end(ops, start_index)
              depth = 1
              (start_index + 1...ops.length).each do |i|
                op = ops[i].opcode
                depth += 1 if op == :LoopStart
                depth -= 1 if op == :LoopEnd
                return i if depth.zero?
              end
              raise "Unbalanced LoopStart at index #{start_index}"
            end

            def remap_registers(ops, remap)
              ops.map do |ins|
                new_inputs = Array(ins.inputs).map { |r| remap.fetch(r, r) }
                LIR::Instruction.new(
                  opcode: ins.opcode, result_register: ins.result_register, stamp: ins.stamp,
                  inputs: new_inputs, immediates: ins.immediates,
                  attributes: ins.attributes, location: ins.location
                )
              end
            end
          end
        end
      end
    end
  end
end
