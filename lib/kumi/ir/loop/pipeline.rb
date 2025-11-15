# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Pipeline
        module_function

        def default
          @default ||= Kumi::IR::Passes::Pipeline.new([Passes::LoopFusion.new])
        end

        def run(graph:, context: {})
          default.run(graph:, context: context)
        end
      end
    end
  end
end
