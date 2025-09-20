# frozen_string_literal: true

require "set"

module Kumi
  module Core
    module Analyzer
      module Passes
        module LIR
          class LoopInvariantCodeMotionPass < PassBase
            LIR = Kumi::Core::LIR
            MAX_PASSES = 10

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
                debug "\n--- LICM: Processing declaration: #{name} ---"
                original_ops = Array(payload[:operations])
                optimized_ops = optimize_block(original_ops)
                new_ops_by_decl[name] = { operations: optimized_ops }
                changed ||= (original_ops != optimized_ops)
              end

              [new_ops_by_decl, changed]
            end

            def optimize_block(ops, depth = 0)
              new_ops = []
              i = 0
              while i < ops.length
                ins = ops[i]
                prefix = "  " * depth

                if ins.opcode == :LoopStart
                  debug "#{prefix}> Found LoopStart(#{ins.attributes[:id]})"
                  end_index = find_matching_loop_end(ops, i)
                  loop_body = ops[(i + 1)...end_index]

                  optimized_nested_body = optimize_block(loop_body, depth + 1)

                  all_hoisted_ops = []
                  current_body = optimized_nested_body
                  pass_num = 0

                  while true
                    pass_num += 1
                    debug "#{prefix}  - Hoisting Pass ##{pass_num} for Loop(#{ins.attributes[:id]})"

                    defs_in_loop = get_defs_in_ops(current_body)
                    defs_in_loop.add(ins.attributes[:as_element])
                    defs_in_loop.add(ins.attributes[:as_index])
                    debug "#{prefix}    - Defs inside loop: #{defs_in_loop.to_a.sort.join(', ')}"

                    hoisted_this_pass, remaining_body = current_body.partition do |body_ins|
                      is_invariant(body_ins, defs_in_loop, prefix, depth)
                    end

                    if hoisted_this_pass.empty?
                      debug "#{prefix}    - Convergence. No more invariants found."
                      break
                    end

                    debug "#{prefix}    - Hoisted #{hoisted_this_pass.size} instruction(s) this pass."
                    all_hoisted_ops.concat(hoisted_this_pass)
                    current_body = remaining_body
                  end

                  new_ops.concat(all_hoisted_ops)
                  new_ops << ins
                  new_ops.concat(current_body)
                  new_ops << ops[end_index]
                  debug "#{prefix}< Finished LoopStart(#{ins.attributes[:id]})"

                  i = end_index + 1
                else
                  new_ops << ins
                  i += 1
                end
              end
              new_ops
            end

            def is_invariant(ins, defs_in_loop, prefix, depth)
              prefix_inner = "#{prefix}      "
              debug "#{prefix_inner}- Checking: #{ins.result_register || '(no result)'} = #{ins.opcode}(#{ins.inputs.join(', ')})"

              unless ins.pure?
                debug "#{prefix_inner}  - REJECT: Instruction is not pure."
                return false
              end

              invariant_inputs = (Set.new(Array(ins.inputs)) & defs_in_loop).empty?

              unless invariant_inputs
                offending_defs = (Set.new(Array(ins.inputs)) & defs_in_loop).to_a
                debug "#{prefix_inner}  - REJECT: Depends on loop-variant registers: #{offending_defs.join(', ')}"
                return false
              end

              debug "#{prefix_inner}  - ACCEPT: Hoisting instruction."
              true
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
