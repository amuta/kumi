# frozen_string_literal: true

require_relative "support/instruction_cloner"

module Kumi
  module IR
    module DF
      module Passes
        class BroadcastSimplify < Kumi::IR::Passes::Base
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
            axes_by_reg = {}
            new_instructions = []

            block.each do |instr|
              new_inputs = instr.inputs.map { |reg| canonical_reg(reg, replacements) }

              if removable_broadcast?(instr, new_inputs, axes_by_reg)
                replacements[instr.result] = new_inputs.first
                next
              end

              cloned = Support::InstructionCloner.clone(instr, new_inputs)
              new_instructions << cloned
              axes_by_reg[cloned.result] = cloned.axes if cloned.result
            end

            Kumi::IR::Base::Block.new(name: block.name, instructions: new_instructions)
          end

          def removable_broadcast?(instr, inputs, axes_by_reg)
            return false unless instr.opcode == :axis_broadcast

            src = inputs.first
            src_axes = axes_by_reg[src]
            return false unless src_axes

            src_axes == instr.axes
          end

          def canonical_reg(reg, replacements)
            seen = []
            while replacements.key?(reg) && !seen.include?(reg)
              seen << reg
              reg = replacements[reg]
            end
            reg
          end
        end
      end
    end
  end
end
