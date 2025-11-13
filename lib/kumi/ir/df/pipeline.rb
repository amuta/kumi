# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Pipeline
        module_function

        def default
          @default ||= Kumi::IR::Passes::Pipeline.new(
            default_passes
          )
        end

        def run(graph:, context: {})
          default.run(graph:, context:)
        end

        def default_passes
          [] # Placeholder: passes will be appended here as they are implemented.
        end
      end
    end
  end
end
