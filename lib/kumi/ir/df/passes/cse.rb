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
              blocks: new_blocks,
              return_stamp: fn.return_stamp
            )
          end

          def rewrite_block(block)
            replacements = {}
            memo = {}
            new_instructions = []

            block.each do |instr|
              new_inputs = instr.uses.map { |reg| replacements.fetch(reg, reg) }

              signature = instr.value_signature(inputs: new_inputs, include_axes: true, include_dtype: true)

              if signature && memo.key?(signature)
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
