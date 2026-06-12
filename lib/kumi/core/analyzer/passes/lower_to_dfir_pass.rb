# frozen_string_literal: true

require "kumi/ir/df"

module Kumi
  module Core
    module Analyzer
      module Passes
        class LowerToDFIRPass < PassBase
          reads :snast_module, :input_table, :registry
          optional_reads :imported_schemas, :precomputed_plan_by_fqn
          writes :df_module, :df_module_unoptimized

          def run(_errors)
            snast_module = get_state(:snast_module, required: true)
            registry = get_state(:registry, required: true)
            input_table = get_state(:input_table, required: true)
            imported_schemas = get_state(:imported_schemas, required: false) || {}

            lowered = Kumi::IR::DF::Lower.new(
              snast_module:,
              registry:,
              input_table:
            ).call

            context = {
              registry:,
              input_table:,
              imported_schemas:,
              input_plans: get_state(:precomputed_plan_by_fqn, required: false) || {}
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
