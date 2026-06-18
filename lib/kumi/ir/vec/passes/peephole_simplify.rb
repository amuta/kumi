# frozen_string_literal: true

module Kumi
  module IR
    module Vec
      module Passes
        class PeepholeSimplify < Kumi::IR::Passes::Base
          require_relative "support/instruction_cloner"

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
                inputs = instr.uses.map { |reg| replacements.fetch(reg, reg) }
                result = instr.defs.first

                case instr.opcode
                when :select
                  if inputs[1] == inputs[2]
                    replacements[result] = inputs[1] if result
                    next
                  end
                  new_instrs << rebuild(instr, inputs)
                when :map
                  simplified = simplify_map(instr, inputs)
                  if simplified
                    replacements[result] = simplified if result
                  else
                    new_instrs << rebuild(instr, inputs)
                  end
                else
                  new_instrs << rebuild(instr, inputs)
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

          # Keep an instruction with its rewritten inputs, not the stale
          # original. An earlier simplification (a collapsed select, a folded
          # and/or map) records its result in `replacements`; downstream
          # instructions that consumed it must be rebuilt to point at the
          # replacement, or they reference a register this pass just deleted.
          def rebuild(instr, inputs)
            return instr if instr.uses.empty?

            Support::InstructionCloner.clone(instr, inputs)
          end

          def simplify_map(instr, inputs)
            fn = instr.attributes[:fn]
            return nil unless %i[core.or core.and].include?(fn)

            return unless inputs[0] == inputs[1]

            inputs[0]
          end
        end
      end
    end
  end
end
