# frozen_string_literal: true

require "set"

module Kumi
  module IR
    module Vec
      module Passes
        class Dce < Kumi::IR::Passes::Base
          def run(graph:, context: {})
            new_functions = graph.functions.values.map { prune_function(_1) }
            Kumi::IR::Vec::Module.new(name: graph.name, functions: new_functions)
          end

          private

          def prune_function(function)
            new_blocks = function.blocks.map { prune_block(_1) }
            Kumi::IR::Base::Function.new(
              name: function.name,
              parameters: function.parameters,
              blocks: new_blocks,
              return_stamp: function.return_stamp
            )
          end

          def prune_block(block)
            instructions = block.instructions
            live = Set.new
            last_result = instructions.last&.result
            live << last_result if last_result

            kept = []
            instructions.reverse_each do |instr|
              result = instr.result
              if result && !live.include?(result)
                next
              end

              kept << instr
              Array(instr.inputs).each do |input|
                live << input if input.is_a?(Symbol)
              end
            end

            Kumi::IR::Base::Block.new(name: block.name, instructions: kept.reverse)
          end
        end
      end
    end
  end
end
