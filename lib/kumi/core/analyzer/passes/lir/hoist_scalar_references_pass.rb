# frozen_string_literal: true

require "set"

module Kumi
  module Core
    module Analyzer
      module Passes
        module LIR
          class HoistScalarReferencesPass < PassBase
            LIR = Kumi::Core::LIR
            MAX_PASSES = 10

            def run(_errors)
              current_ops = get_state(:lir_module)

              MAX_PASSES.times do |pass_num|
                debug "\n[HOIST] Starting Pass ##{pass_num + 1}"
                new_ops, changed = run_one_pass(current_ops)
                return state.with(:lir_module, new_ops.freeze).with(:lir_01_hoist_scalar_references_pass, new_ops) unless changed

                current_ops = new_ops
              end

              raise "HoistScalarReferencesPass did not converge after #{MAX_PASSES} passes."
            end

            private

            def run_one_pass(ops_by_decl)
              changed = false
              new_ops_by_decl = {}

              ops_by_decl.each do |name, payload|
                original_ops = Array(payload[:operations])
                debug "[HOIST] Optimizing declaration: #{name} (#{original_ops.size} initial instructions)"
                optimized_ops = optimize_decl(original_ops)
                new_ops_by_decl[name] = { operations: optimized_ops }
                changed ||= original_ops.size != optimized_ops.size || original_ops != optimized_ops
              end

              [new_ops_by_decl, changed]
            end

            def optimize_decl(ops)
              hoist_in_block(ops)
            end

            def hoist_in_block(ops, current_depth = 0)
              new_ops = []
              i = 0
              while i < ops.length
                ins = ops[i]

                if ins.opcode == :LoopStart
                  loop_id = ins.attributes[:id]
                  debug_indent = "  " * current_depth
                  debug "#{debug_indent}[HOIST] > Entering Loop #{loop_id}"

                  end_index = find_matching_loop_end(ops, i)
                  loop_body = ops[(i + 1)...end_index]

                  optimized_body = hoist_in_block(loop_body, current_depth + 1)

                  debug "#{debug_indent}[HOIST] | Analyzing body of Loop #{loop_id} for hoisting..."
                  hoisted_ops, remaining_ops = optimized_body.partition do |body_ins|
                    is_hoistable = is_hoistable_scalar_load?(body_ins)
                    debug "#{debug_indent}[HOIST]   - Hoisting: #{body_ins.inspect}" if is_hoistable
                    is_hoistable
                  end

                  debug "#{debug_indent}[HOIST]   (No hoistable instructions found in this loop)" if hoisted_ops.empty?

                  new_ops.concat(hoisted_ops)
                  new_ops << ins
                  new_ops.concat(remaining_ops)
                  new_ops << ops[end_index]

                  debug "#{debug_indent}[HOIST] < Exiting Loop #{loop_id}"
                  i = end_index + 1
                else
                  new_ops << ins
                  i += 1
                end
              end
              new_ops
            end

            def is_hoistable_scalar_load?(ins)
              ins.opcode == :LoadDeclaration && Array(ins.attributes[:axes]).empty?
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

            # Simple debug helper, assuming a `debug` method might exist on PassBase
            def debug(msg)
              # In a real scenario, you might have a logger.
              # For now, we can just print to stdout if a flag is set.
              puts msg if ENV["DEBUG"]
            end
          end
        end
      end
    end
  end
end
