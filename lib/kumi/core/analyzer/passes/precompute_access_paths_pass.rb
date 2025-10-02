# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Builds navigation artifacts from AccessPlannerV2.navigation_steps.
        #
        # Output state key: :precomputed_plan_by_fqn
        # Map<fqn,String> => {
        #   steps:               Array<Hash(sym keys)>,
        #   loop_ixs:            Array<Integer>,
        #   head_path_by_loop:   Hash<Integer, Array<[Symbol(:input|:field), Symbol(key)]>>,
        #   between_loops:       Hash<[Integer,Integer], Array<Symbol>>
        # }
        class PrecomputeAccessPathsPass < PassBase
          def run(_errors)
            plans = get_state(:ir_input_plans, required: true)
            out   = {}
            plans.each do |p|
              out[p.path_fqn.to_s] = build_for_plan(p).freeze
            end
            state.with(:precomputed_plan_by_fqn, out.freeze)
          end

          private

          def build_for_plan(plan)
            steps = Array(plan.navigation_steps).map { |h| h.transform_keys!(&:to_sym) }.freeze
            loop_ixs = steps.each_index.select { |i| steps[i][:kind] == "array_loop" }.freeze

            head_path_by_loop = {}
            loop_ixs.each { |li| head_path_by_loop[li] = compress_head_path(steps, li).freeze }

            between_loops = {}
            loop_ixs.each_with_index do |li_from, i|
              ((i + 1)...loop_ixs.length).each do |j|
                li_to = loop_ixs[j]
                between_loops[[li_from, li_to]] = compress_between(steps, li_from, li_to).freeze
              end
            end

            {
              steps: steps,
              loop_ixs: loop_ixs,
              head_path_by_loop: head_path_by_loop.freeze,
              between_loops: between_loops.freeze
            }
          end

          # steps[0..li] → [[:input, k] or [:field, k], ...] to reach the array for loop li
          def compress_head_path(steps, li)
            acc = []
            steps[0..li].each do |s|
              case s[:kind]
              when "property_access"
                acc << [:field, s[:key].to_sym]
              when "array_loop"
                if s[:key]
                  acc << if acc.empty?
                           [:input, s[:key].to_sym]
                         else
                           [:field, s[:key].to_sym]
                         end
                end
                break
              when "element_access"
                # no hop
              end
            end
            acc
          end

          # keys from element(li_from) → collection(li_to)
          def compress_between(steps, li_from, li_to)
            raise ArgumentError, "order" unless li_from < li_to

            keys = []
            ((li_from + 1)..li_to).each do |i|
              s = steps[i]
              case s[:kind]
              when "property_access"
                keys << s[:key].to_sym
              when "array_loop"
                keys << s[:key].to_sym if s[:key]
                break
              when "element_access"
                # no hop
              end
            end
            keys
          end
        end
      end
    end
  end
end
