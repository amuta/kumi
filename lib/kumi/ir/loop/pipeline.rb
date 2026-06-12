# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Pipeline
        module_function

        def default
          @default ||= Kumi::IR::Passes::Pipeline.new(default_passes)
        end

        def run(graph:, context: {})
          default.run(graph: graph, context: context)
        end

        def default_passes
          [
            Passes::LoopFusion.new,
            Passes::ArrayContraction.new
          ]
        end
      end
    end
  end
end
