# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Creates canonical input plans by selecting preferred access mode for each unique input path
        #
        # Input: state[:access_plans] (multiple modes per path), state[:input_table] (for dtype lookup)
        # Output: state[:ir_input_plans] (one plan per unique input path)
        class SynthesizeAccessChainsPass < PassBase
          def run(errors)
            access_plans = get_state(:access_plans, required: true)
            input_table = get_state(:input_table, required: true)

            input_plans = build_input_plans(access_plans, input_table, errors)

            debug "Generated #{input_plans.size} canonical input plans"

            state.with(:ir_input_plans, input_plans.freeze)
          end

          private

          def build_input_plans(access_plans, input_table, errors)
            input_plans = []

            access_plans.each do |path_string, plan_list|
              next if plan_list.nil? || plan_list.empty?

              selected_plan = select_preferred_plan(plan_list)
              next unless selected_plan

              path_array = path_string.split(".").map(&:to_sym)
              input_info = input_table[path_array]

              unless input_info
                add_error(errors, nil, "No input table entry for path: #{path_array.inspect}")
                next
              end

              input_plan = build_input_plan(path_array, selected_plan, input_info)
              input_plans << input_plan

              debug "Synthesized canonical plan for #{path_string}: #{input_plan[:name]} (mode: #{selected_plan.mode})"
            end

            input_plans
          end

          def build_input_plan(path_array, selected_plan, input_info)
            {
              type: :input,
              name: "in_#{path_array.last}",
              path: path_array,
              axes: selected_plan.containers,
              dtype: input_info[:dtype],
              chain: selected_plan.chain
            }.freeze
          end

          def select_preferred_plan(plan_list)
            # Deterministic selection: :read XOR :each_indexed
            read_plan = plan_list.find { |plan| plan.mode == :read }
            each_indexed_plan = plan_list.find { |plan| plan.mode == :each_indexed }

            if read_plan && each_indexed_plan
              raise "Invalid state: path has both :read and :each_indexed modes"
            elsif read_plan
              read_plan
            elsif each_indexed_plan
              each_indexed_plan
            else
              raise "No :read or :each_indexed plan found for path"
            end
          end
        end
      end
    end
  end
end
