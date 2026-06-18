# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class InputAccessPlannerPass < PassBase
          reads :input_metadata
          writes :input_table, :index_table

          def run(_errors)
            input_metadata = get_state(:input_metadata)

            options = {
              on_missing: :error,
              key_policy: :indifferent
            }

            planner = Kumi::Core::Compiler::AccessPlannerV2.plan(input_metadata, options, debug_on: debug_enabled?)

            state.with(:input_table, planner.plans.freeze).with(:index_table, planner.index_table.freeze)
          end
        end
      end
    end
  end
end
