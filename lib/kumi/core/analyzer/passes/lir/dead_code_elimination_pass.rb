# frozen_string_literal: true

require "set"

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
              ops_by_decl =
                get_state(:lir_module, required: false)

              out = {}
              ops_by_decl.each do |name, payload|
                out[name] = { operations: optimize_decl(Array(payload[:operations]), name) }
              end

              out.freeze

              state.with(:lir_module, out)
            end

            private

            def optimize_decl(ops, decl_name)
              debug "[DCE] Optimizing declaration: #{decl_name} (#{ops.size} initial instructions)"
              debug "=================================================="

              live = Set.new
              new_ops = []

              ops.reverse_each.with_index do |ins, i|
                original_index = ops.size - 1 - i
                debug "\n[DCE] [#{original_index}] Processing: #{ins.inspect}"
                debug "[DCE]   Live set before: #{live.to_a.sort.inspect}"

                is_side_effect = ins.side_effect?
                result_in_live = ins.result_register && live.include?(ins.result_register)
                is_live = is_side_effect || result_in_live

                if is_live
                  reason = []
                  reason << "has side effect" if is_side_effect
                  reason << "result #{ins.result_register} is live" if result_in_live
                  debug "[DCE]   -> KEEPING (Reason: #{reason.join('; ')})"

                  new_ops.unshift(ins)

                  if ins.result_register
                    live.delete(ins.result_register)
                    debug "[DCE]     - Removing defined reg from live set: #{ins.result_register}"
                  end

                  Array(ins.inputs).each do |input|
                    next unless input

                    live.add(input)
                    debug "[DCE]     + Adding used reg to live set: #{input}"
                  end
                  debug "[DCE]   Live set after:  #{live.to_a.sort.inspect}"
                else
                  debug "[DCE]   -> DROPPING (Reason: no side effect and result #{ins.result_register || 'n/a'} is not live)"
                end
              end

              debug "\n[DCE] Finished optimizing #{decl_name}."
              debug "[DCE] Final instruction count: #{new_ops.size} (removed #{ops.size - new_ops.size})"
              debug "=================================================="
              new_ops
            end
          end
        end
      end
    end
  end
end
