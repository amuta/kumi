# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Creates canonical input plans (one per unique input path).
        #
        # Input:
        #   - state[:access_plans] : { "a.b.c" => [AccessPlan, ...] }  (your new planner should emit exactly 1 per path)
        #   - state[:input_table]  : { [:a,:b,:c] => { dtype:, key_policy:, on_missing: } }
        #
        # Output:
        #   - state[:ir_input_plans] : [ Core::IRV2::InputPlan ]
        #
        # Invariants enforced here:
        #   - Exactly one plan is selected per path (if more are present, prefer :read; otherwise raise).
        #   - The chain must end in a leaf: "field_leaf" or "element_leaf".
        #   - Axis count must match the number of array hops in the chain (array_field + array_element).
        class SynthesizeAccessChainsPass < PassBase
          def run(errors)
            access_plans = get_state(:access_plans_v2, required: true)
            input_table  = get_state(:input_table, required: true)

            input_plans = build_input_plans(access_plans, input_table, errors)
            debug "Generated #{input_plans.size} canonical input plans"

            state.with(:ir_input_plans, input_plans.freeze)
          end

          private

          def build_input_plans(access_plans, input_table, errors)
            input_plans = []

            access_plans.each do |path_string, plan_list|
              next if plan_list.nil? || plan_list.empty?

              selected = select_preferred_plan(plan_list)
              next unless selected

              source_path = path_string.split(".").map(&:to_sym)
              input_info = input_table[source_path]
              unless input_info
                add_error(errors, nil, "No input table entry for path: #{source_path.inspect}")
                next
              end

              # NEW: validate with dtype awareness
              # validate_chain!(path_string, selected)

              input_plans << build_input_plan(source_path, selected, input_info)
              debug "Synthesized canonical plan for #{path_string}: #{source_path.join('.')} (mode: #{selected.mode})"
            end

            input_plans
          end

          def build_input_plan(source_path, selected, info)
            Core::IRV2::InputPlan.new(
              source_path: source_path,
              axes: selected.containers, # axis lineage from planner
              dtype: info[:dtype], # authoritative dtype
              key_policy: info[:key_policy] || selected.key_policy || "indifferent",
              missing_policy: info[:on_missing] || selected.on_missing || "error",
              access_chain: selected.chain # canonical chain: array_field/array_element/field_leaf/element_leaf
            )
          end

          def select_preferred_plan(plan_list)
            read = plan_list.find { |p| p.mode == :read }
            return read if read

            ei = plan_list.find { |p| p.mode == :each_indexed }
            return ei if ei

            raise "No usable plan (:read or :each_indexed) found for path"
          end

          def validate_chain!(path_string, plan)
            chain = plan.chain || []
            raise "Invalid chain for #{path_string}: empty" if chain.empty?

            last_kind = chain.last["kind"]
            allowed_last = %w[field_leaf element_leaf array_field array_element]
            unless allowed_last.include?(last_kind)
              msg = "Invalid chain for #{path_string}: terminal kind must be one of " \
                    "#{allowed_last.join(', ')}, got #{last_kind.inspect}\n  " \
                    "Full chain:\n" + chain.map { |x| "    " + x.inspect }.join("\n")
              raise msg
            end

            # Hop count must match axis lineage count.
            axis_hops = chain.count { |s| %w[array_field array_element].include?(s["kind"]) }
            return if axis_hops == plan.containers.length

            raise "Axis mismatch for #{path_string}: chain hops=#{axis_hops} vs " \
                  "axes=#{plan.containers.length} (#{plan.containers.map(&:to_s).join(',')})"
          end
        end
      end
    end
  end
end
