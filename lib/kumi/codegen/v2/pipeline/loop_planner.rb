# frozen_string_literal: true

module Kumi
  module Codegen
    module V2
      module Pipeline
        module LoopPlanner
          module_function
          def run(ctx)
            rank = ctx[:axes].length
            loops = ctx[:axes].map.with_index { |axis, depth| { depth:, axis: } }
            { rank:, loops:, index_names: loops.map { |l| "i#{l[:depth]}" } }
          end
        end
      end
    end
  end
end