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
              new_inputs = instr.inputs.map { |reg| canonical_reg(reg, replacements) }

              if instr.opcode == :axis_shift
                key = shift_key(instr, new_inputs)
                if key && shift_cache.key?(key)
                  replacements[instr.result] = shift_cache[key]
                  next
                end
              end

              cloned = Support::InstructionCloner.clone(instr, new_inputs)
              new_instructions << cloned

              if instr.opcode == :axis_shift && cloned.result
                key = shift_key(instr, new_inputs)
                shift_cache[key] = cloned.result if key
              end
            end

            Kumi::IR::Base::Block.new(name: block.name, instructions: new_instructions)
          end

          def canonical_reg(reg, replacements)
            while replacements.key?(reg)
              reg = replacements[reg]
            end
            reg
          end

          def shift_key(instr, inputs)
            source = inputs.first
            return nil unless source

            attrs = instr.attributes || {}
            [
              source,
              attrs[:axis]&.to_sym,
              attrs[:offset],
              attrs[:policy]&.to_sym,
              Array(instr.axes),
              instr.dtype
            ]
          end
        end
      end
    end
  end
end
