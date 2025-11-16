# frozen_string_literal: true

module Kumi
  module IR
    module Vec
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
            Passes::ConstantPropagation.new,
            Passes::Gvn.new,
            Passes::AxisCanonicalization.new,
            Passes::PeepholeSimplify.new,
            Passes::StencilDetection.new,
            Passes::Dce.new
          ]
        end
      end
    end
  end
end
