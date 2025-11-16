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
            Passes::DeclInlining.new,
            Passes::LoadDedup.new,
            Passes::BroadcastSimplify.new,
            Passes::TupleFoldCanonicalization.new,
            Passes::CSE.new,
            Passes::StencilCSE.new,
            Passes::ImportInlining.new,
            Passes::TupleToObject.new
          ]
        end
      end
    end
  end
end
