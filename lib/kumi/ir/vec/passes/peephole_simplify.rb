# frozen_string_literal: true

module Kumi
  module IR
    module Vec
      module Passes
        class PeepholeSimplify < Kumi::IR::Passes::Base
          def run(graph:, context: {})
            new_functions = graph.functions.values.map { simplify_function(_1) }
            Kumi::IR::Vec::Module.new(name: graph.name, functions: new_functions)
          end

          private

          def simplify_function(function)
            replacements = {}
            new_blocks = function.blocks.map do |block|
              new_instrs = []
              block.instructions.each do |instr|
                inputs = instr.inputs.map { |reg| replacements.fetch(reg, reg) }

                case instr.opcode
                when :select
                  if inputs[1] == inputs[2]
                    replacements[instr.result] = inputs[1]
                    next
                  end
                  new_instrs << instr
                when :map
                  simplified = simplify_map(instr, inputs)
                  if simplified
                    replacements[instr.result] = simplified
                  else
                    new_instrs << instr
                  end
                else
                  new_instrs << instr
                end
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

          def simplify_map(instr, inputs)
            fn = instr.attributes[:fn]
            return nil unless fn == :"core.or" || fn == :"core.and"

            if inputs[0] == inputs[1]
              inputs[0]
            else
              nil
            end
          end
        end
      end
    end
  end
end
