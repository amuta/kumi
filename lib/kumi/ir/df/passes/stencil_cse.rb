# frozen_string_literal: true

require_relative "support/instruction_cloner"

module Kumi
  module IR
    module DF
      module Passes
        class StencilCSE < Kumi::IR::Passes::Base
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
            shift_cache = {}
            new_instructions = []

            block.each do |instr|
              new_inputs = instr.uses.map { |reg| canonical_reg(reg, replacements) }

              if instr.opcode == :axis_shift
                key = shift_key(instr, new_inputs)
                if key && shift_cache.key?(key)
                  if (result = instr.defs.first)
                    replacements[result] = shift_cache[key]
                  end
                  next
                end
              end

              cloned = Support::InstructionCloner.clone(instr, new_inputs)
              new_instructions << cloned

              if instr.opcode == :axis_shift && cloned.defs.first
                key = shift_key(instr, new_inputs)
                shift_cache[key] = cloned.defs.first if key
              end
            end

            Kumi::IR::Base::Block.new(name: block.name, instructions: new_instructions)
          end

          def canonical_reg(reg, replacements)
            reg = replacements[reg] while replacements.key?(reg)
            reg
          end

          def shift_key(instr, inputs)
            instr.value_signature(inputs: inputs, include_axes: true, include_dtype: true)
          end
        end
      end
    end
  end
end
