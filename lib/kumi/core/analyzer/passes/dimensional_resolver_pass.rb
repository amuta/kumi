# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Pass that resolves dimensional execution contexts for all declarations
        # Determines where each declaration should execute based on input refence depth/dimension
        class DimensionalResolverPass < PassBase
          def run(errors)
            dependency_graph = get_state(:dependencies)
            input_metadata = get_state(:inputs)

            dimensional_contexts = DimensionalResolver.analyze_all(dependency_graph, input_metadata)

            state.with(:dimensional_contexts, dimensional_contexts.freeze)
          end
        end
      end
    end
  end
end