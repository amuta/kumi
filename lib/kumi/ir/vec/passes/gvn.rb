# frozen_string_literal: true

module Kumi
  module IR
    module Vec
      module Passes
        class Gvn < Kumi::IR::Passes::Base
          def run(graph:, context: {})
            new_functions = graph.functions.values.map { reuse_values(_1) }
            Kumi::IR::Vec::Module.new(name: graph.name, functions: new_functions)
          end

          private

          def reuse_values(function)
            replacements = {}
            table = {}
            new_blocks = function.blocks.map do |block|
              new_instrs = []
              block.instructions.each do |instr|
                inputs = instr.inputs.map { |reg| replacements.fetch(reg, reg) }
                signature = build_signature(instr, inputs)

                if signature && table.key?(signature)
                  replacements[instr.result] = table[signature]
                  next
                end

                table[signature] = instr.result if signature
                new_instrs << instr
              end

              Kumi::IR::Base::Block.new(name: block.name, instructions: new_instrs)
            end

            Kumi::IR::Base::Function.new(
              name: function.name,
              parameters: function.parameters,
              blocks: new_blocks,
              return_stamp: function.return_stamp
            )
          end

          def build_signature(instr, inputs)
            return nil unless instr.result
            return nil if instr.opcode == :load_input

            attrs = instr.attributes || {}
            [
              instr.opcode,
              inputs,
              attrs.sort_by { |k, _| k.to_s }
            ]
          end
        end
      end
    end
  end
end
