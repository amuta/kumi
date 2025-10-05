# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class InputAccessPlannerPass < PassBase
          def run(errors)
            input_metadata = get_state(:input_metadata)

            options = {
              on_missing: :error,
              key_policy: :indifferent
            }

            # TODO : Allow by input definition on policies or at least general policy definition
            # plans = Kumi::Core::Compiler::AccessPlanner.plan(input_metadata, options)

            plans_v2 = Kumi::Core::Compiler::AccessPlannerV2.plan(input_metadata, options, debug_on: debug_enabled?)

            # Quick validation
            # validate_plans!(plans, errors)

            # Create new state with access plans
            state.with(:input_table, plans_v2.freeze)
          end

          private

          def validate_plans!(plans, errors)
            plans.each do |path, plan_list|
              add_error(errors, nil, "No access plans generated for path: #{path}") if plan_list.nil? || plan_list.empty?

              plan_list&.each do |plan|
                unless plan[:operations].is_a?(Array)
                  add_error(errors, nil, "Invalid operations for path #{path}: expected Array, got #{plan[:operations].class}")
                end

                unless plan[:mode].is_a?(Symbol)
                  add_error(errors, nil, "Invalid mode for path #{path}: expected Symbol, got #{plan[:mode].class}")
                end
              end
            end
          end
        end
      end
    end
  end
end
