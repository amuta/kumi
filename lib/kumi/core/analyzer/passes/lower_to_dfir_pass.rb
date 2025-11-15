# frozen_string_literal: true

require "kumi/ir/df"

module Kumi
  module Core
    module Analyzer
      module Passes
        class LowerToDFIRPass < PassBase
          def run(_errors)
            snast_module = get_state(:snast_module, required: true)
            registry = get_state(:registry, required: true)
            input_table = get_state(:input_table, required: true)
            input_metadata = get_state(:input_metadata, required: false) || {}
            imported_schemas = get_state(:imported_schemas, required: false) || {}

            lowered = Kumi::IR::DF::Lower.new(
              snast_module:,
              registry:,
              input_table:,
              input_metadata:
            ).call

            context = {
              registry:,
              input_table:,
              imported_schemas:
            }
            optimized = Kumi::IR::DF::Pipeline.run(graph: lowered, context:)

            state.with(:df_module_unoptimized, lowered.freeze)
                 .with(:df_module, optimized.freeze)
          end
        end
      end
    end
  end
end
