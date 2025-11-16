# frozen_string_literal: true

require_relative "support/instruction_cloner"

module Kumi
  module IR
    module Vec
      module Passes
        class AxisCanonicalization < Kumi::IR::Passes::Base
          def run(graph:, context: {})
            new_functions = graph.functions.values.map { normalize_function(_1) }
            Kumi::IR::Vec::Module.new(name: graph.name, functions: new_functions)
          end

          private

          def normalize_function(function)
            new_blocks = function.blocks.map { normalize_block(_1) }
            Kumi::IR::Base::Function.new(
              name: function.name,
              parameters: function.parameters,
              blocks: new_blocks,
              return_stamp: function.return_stamp
            )
          end

          def normalize_block(block)
            new_instrs = block.instructions.map do |instr|
              canonical_axes = Array(instr.axes).map(&:to_sym)
              canonical_axes = canonical_axes.each_with_object([]) do |axis, acc|
                acc << axis unless acc.include?(axis)
              end
              invariant = canonical_axes.empty?

              if canonical_axes == Array(instr.axes) && instr.metadata[:vec_invariant] == invariant
                instr
              else
                metadata = instr.metadata.merge(vec_invariant: invariant, axes: canonical_axes)
                Passes::Support::InstructionCloner.clone(
                  instr,
                  instr.inputs,
                  attributes: instr.attributes,
                  metadata: metadata,
                  result: instr.result,
                  axes: canonical_axes,
                  dtype: instr.dtype
                )
              end
            end

            Kumi::IR::Base::Block.new(name: block.name, instructions: new_instrs)
          end
        end
      end
    end
  end
end
