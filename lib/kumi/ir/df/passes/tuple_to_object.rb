# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Passes
        class TupleToObject < Kumi::IR::Passes::Base
          def run(graph:, context: {})
            new_functions = graph.functions.values.map { rewrite_function(_1) }
            Kumi::IR::DF::Graph.new(name: graph.name, functions: new_functions)
          end

          private

          def rewrite_function(function)
            new_blocks = function.blocks.map { rewrite_block(_1) }
            Kumi::IR::DF::Function.new(
              name: function.name,
              parameters: function.parameters,
              blocks: new_blocks,
              return_stamp: function.return_stamp
            )
          end

          def rewrite_block(block)
            new_instructions = block.instructions.map do |instr|
              if instr.opcode == :array_build && tuple_dtype?(instr)
                rewrite_array_build(instr)
              else
                instr
              end
            end
            Kumi::IR::Base::Block.new(name: block.name, instructions: new_instructions)
          end

          def tuple_dtype?(instr)
            dtype = instr.metadata[:dtype] || instr.dtype
            dtype.respond_to?(:element_types)
          end

          def rewrite_array_build(instr)
            dtype = instr.metadata[:dtype] || instr.dtype
            keys = dtype.element_types.each_index.map { |idx| :"_#{idx}" }
            Ops::MakeObject.new(
              result: instr.result,
              inputs: instr.inputs,
              keys: keys,
              axes: instr.axes,
              dtype: instr.metadata[:dtype] || instr.dtype,
              metadata: instr.metadata
            )
          end
        end
      end
    end
  end
end
