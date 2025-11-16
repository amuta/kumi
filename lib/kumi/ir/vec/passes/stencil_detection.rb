# frozen_string_literal: true

require_relative "support/instruction_cloner"

module Kumi
  module IR
    module Vec
      module Passes
        class StencilDetection < Kumi::IR::Passes::Base
          def run(graph:, context: {})
            new_functions = graph.functions.values.map { tag_function(_1) }
            Kumi::IR::Vec::Module.new(name: graph.name, functions: new_functions)
          end

          private

          def tag_function(function)
            new_blocks = function.blocks.map { tag_block(_1) }
            Kumi::IR::Base::Function.new(
              name: function.name,
              parameters: function.parameters,
              blocks: new_blocks,
              return_stamp: function.return_stamp
            )
          end

          def tag_block(block)
            shifts_by_source = Hash.new { |h, k| h[k] = [] }
            block.instructions.each do |instr|
              next unless instr.opcode == :axis_shift

              shifts_by_source[instr.inputs.first] << instr
            end

            tagged_sources = shifts_by_source.select { |_src, instrs| instrs.length >= 4 }.keys
            return block if tagged_sources.empty?

            new_instrs = block.instructions.map do |instr|
              next instr unless instr.opcode == :axis_shift
              next instr unless tagged_sources.include?(instr.inputs.first)

              metadata = instr.metadata.merge(vec_stencil: true)
              Passes::Support::InstructionCloner.clone(
                instr,
                instr.inputs,
                attributes: instr.attributes,
                metadata: metadata,
                result: instr.result,
                axes: instr.axes,
                dtype: instr.dtype
              )
            end

            Kumi::IR::Base::Block.new(name: block.name, instructions: new_instrs)
          end
        end
      end
    end
  end
end
