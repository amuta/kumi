# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Passes
        # Two classic, syntax-preserving cleanups on the final LoopIR, so both
        # the Ruby and JS emitters get shorter output from one place:
        #
        #   1. Copy propagation. `ref` and `acc_load` emit a bare `x = y` copy
        #      (see the emitters). Since every LoopIR result is assigned once,
        #      rewriting every use of `x` to `y` and dropping the copy is always
        #      safe — it is pure renaming. This collapses chains like
        #      `t15 = t22; t10 = t15 - t23`  =>  `t10 = t22 - t23`, and lets a
        #      function `return` its accumulator directly instead of via a temp.
        #
        #   2. Dead-code elimination. After propagation, an instruction whose
        #      result is read nowhere and which has no side effect (a pure
        #      compute: constant/load/kernel_call/select/make_object/index_read/
        #      array_len/ref/acc_load) is removed. Loop control, pushes, and
        #      accumulator steps are kept — they act through effects, not a read.
        #
        # Neither transform changes evaluation order or which registers are live
        # across loop boundaries, so the scope-aware Loop::Validator still holds.
        class CopyCleanup < Kumi::IR::Passes::Base
          # Opcodes that are pure: their only observable effect is the value they
          # produce, so an unused result means the whole instruction is dead.
          PURE_OPS = %i[
            constant load_input load_field kernel_call select make_object
            ref acc_load array_len index_read shift_read shift_in_bounds
          ].freeze

          # Opcodes that are a bare copy of their single input.
          COPY_OPS = %i[ref acc_load].freeze

          def run(graph:, context: {}) # rubocop:disable Lint/UnusedMethodArgument
            functions = graph.functions.values.map { |fn| process_function(fn) }
            Loop::Module.new(name: graph.name, functions: functions)
          end

          private

          def process_function(function)
            instructions = function.entry_block.instructions

            copies = copy_map(instructions)
            resolved = copies.transform_values { |v| resolve(copies, v) }

            # Propagate copies into every use, then drop instructions that are
            # both a removed copy and dead. We re-derive liveness AFTER remapping
            # so a value that was only kept alive by a now-bypassed copy dies too.
            remapped = instructions.map { |instr| Support.remap(instr, resolved) }
            return_reg = resolved.fetch(function.return_reg, function.return_reg)

            kept = drop_dead(remapped, return_reg)
            return function if kept.size == instructions.size && return_reg == function.return_reg

            block = Base::Block.new(name: function.entry_block.name, instructions: kept)
            Loop::Function.new(name: function.name, parameters: function.parameters, blocks: [block], return_reg: return_reg)
          end

          # result-reg => source-reg for every bare copy. The function's return
          # register is rewritten through this map too, so `return = ref x`
          # simply becomes `return x`.
          def copy_map(instructions)
            instructions.each_with_object({}) do |instr, map|
              next unless COPY_OPS.include?(instr.opcode) && instr.result

              map[instr.result] = instr.inputs.first
            end
          end

          # Iteratively drop pure instructions whose result no one reads. One
          # pass can expose more dead code (a dropped instruction's inputs may
          # now be unread), so repeat until the set is stable.
          def drop_dead(instructions, return_reg)
            loop do
              used = live_registers(instructions, return_reg)
              kept = instructions.reject do |instr|
                PURE_OPS.include?(instr.opcode) && instr.result && !used.key?(instr.result)
              end
              return kept if kept.size == instructions.size

              instructions = kept
            end
          end

          # Every register read by some surviving instruction, plus the return.
          def live_registers(instructions, return_reg)
            used = {}
            used[return_reg] = true if return_reg
            instructions.each do |instr|
              instr.uses.each { |r| used[r] = true }
            end
            used
          end

          def resolve(map, reg)
            seen = {}
            while map.key?(reg)
              raise "copy cycle at #{reg}" if seen[reg]

              seen[reg] = true
              reg = map[reg]
            end
            reg
          end
        end
      end
    end
  end
end
