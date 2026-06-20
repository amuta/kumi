# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Passes
        class CSE < Kumi::IR::Passes::Base
          def run(graph:, context: {})
            functions = graph.functions.values.map { |fn| rewrite_function(fn) }
            Kumi::IR::DF::Graph.new(name: graph.name, functions: functions)
          end

          private

          def rewrite_function(fn)
            new_blocks = fn.blocks.map { |block| rewrite_block(block) }
            Kumi::IR::DF::Function.new(
              name: fn.name,
              parameters: fn.parameters,
              blocks: new_blocks
            )
          end

          def rewrite_block(block)
            replacements = {}
            memo = {}
            new_instructions = []

            # The function's result is the LAST result-bearing instruction, so
            # deduplicating it away would change which value the function
            # returns. Per-output functions make the terminal a structurally
            # unique root today, but the guard keeps the invariant explicit.
            terminal = block.terminal_instruction

            block.each do |instr|
              new_inputs = instr.uses.map { |reg| replacements.fetch(reg, reg) }

              signature = instr.value_signature(inputs: new_inputs, include_axes: true, include_dtype: true)

              if signature && memo.key?(signature) && !instr.equal?(terminal)
                replacements[instr.result] = memo[signature]
                next
              end

              cloned = Support::InstructionCloner.clone(instr, new_inputs)
              new_instructions << cloned
              memo[signature] = cloned.result if signature && cloned.result
            end

            Kumi::IR::Base::Block.new(name: block.name, instructions: new_instructions)
          end
        end
      end
    end
  end
end
