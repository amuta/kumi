# frozen_string_literal: true

module Kumi
  module IR
    module Vec
      module Passes
        class Gvn < Kumi::IR::Passes::Base
          require_relative "support/instruction_cloner"

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
                inputs = instr.uses.map { |reg| replacements.fetch(reg, reg) }
                signature = build_signature(instr, inputs)

                if signature && table.key?(signature)
                  replacements[instr.result] = table[signature]
                  next
                end

                table[signature] = instr.result if signature
                cloned = Support::InstructionCloner.clone(
                  instr,
                  inputs,
                  attributes: instr.attributes,
                  metadata: instr.metadata,
                  result: instr.result,
                  axes: instr.axes,
                  dtype: instr.dtype
                )
                new_instrs << cloned
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
            instr.value_signature(inputs: inputs, include_axes: true, include_dtype: true)
          end
        end
      end
    end
  end
end
