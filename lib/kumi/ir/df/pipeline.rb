# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Pipeline
        module_function

        def default
          @default ||= Kumi::IR::Passes::Pipeline.new(default_passes)
        end

        def run(graph:, context: {})
          default.run(graph:, context: context)
        end

        def default_passes
          [
            Passes::BroadcastSimplify.new
          ]
        end
      end
    end
  end
end
# frozen_string_literal: true

require_relative "passes/broadcast_simplify"
