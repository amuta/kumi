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
              new_inputs = instr.inputs.map { |reg| replacements.fetch(reg, reg) }

              key = memo_key(instr, new_inputs)

              if key && memo.key?(key)
                replacements[instr.result] = memo[key]
                next
              end

              cloned = Support::InstructionCloner.clone(instr, new_inputs)
              new_instructions << cloned
              memo[key] = cloned.result if key && cloned.result
            end

            Kumi::IR::Base::Block.new(name: block.name, instructions: new_instructions)
          end

          def memo_key(instr, inputs)
            return nil if instr.effectful?
            return nil unless instr.result

            [
              instr.opcode,
              inputs,
              normalized_hash(instr.attributes),
              instr.axes,
              instr.dtype
            ]
          end

          def normalized_hash(hash)
            return hash unless hash.is_a?(Hash)

            hash.sort_by { |k, _| k }
          end
        end
      end
    end
  end
end
