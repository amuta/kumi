# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class PrecomputeAccessPathsPass < PassBase
          def run(_errors)
            plans = get_state(:input_table, required: true)
            out   = {}
            plans.each { |p| out[p.path_fqn.to_s] = build_for_plan(p).freeze }
            state.with(:precomputed_plan_by_fqn, out.freeze)
          end

          private

          def build_for_plan(plan)
            # normalize to symbol keys & kinds
            steps = Array(plan.navigation_steps).map { |h| h.to_h.transform_keys!(&:to_sym) }.freeze

            loop_ixs = steps.each_index.select { |i| steps[i][:kind].to_s == "array_loop" }.freeze

            head_path_by_loop = {}
            loop_ixs.each { |li| head_path_by_loop[li] = compress_head_path(steps, li).freeze }

            between_loops = {}
            loop_ixs.each_with_index do |li_from, i|
              ((i + 1)...loop_ixs.length).each do |j|
                li_to = loop_ixs[j]
                between_loops[[li_from, li_to]] = compress_between(steps, li_from, li_to).freeze
              end
            end

            last_loop_li = loop_ixs.last
            tail_range   = last_loop_li ? ((last_loop_li + 1)..(steps.length - 1)) : (0..(steps.length - 1))
            tail_steps   = tail_range.to_a.empty? ? [] : steps[tail_range]
            tail_keys_after_last_loop = tail_steps.select { |s| s[:kind].to_s == "property_access" }
                                                  .map { |s| s[:key].to_sym }.freeze
            element_terminal = tail_steps.any? { |s| s[:kind].to_s == "element_access" }

            {
              steps: steps,
              loop_ixs: loop_ixs,
              loop_axes: loop_ixs.map { |i| steps[i][:axis].to_sym }.freeze,
              axis_to_loop: loop_ixs.map { |i| [steps[i][:axis].to_sym, i] }.to_h.freeze,
              head_path_by_loop: head_path_by_loop.freeze,
              between_loops: between_loops.freeze,
              last_loop_li: last_loop_li,
              tail_keys_after_last_loop: tail_keys_after_last_loop,
              element_terminal: element_terminal
            }
          end

          # steps[0..li] → [[:input, k] or [:field, k], ...] to reach the array for loop li
          # NOTE: now :array_loop has NO :key; the key came from the prior property_access.
          def compress_head_path(steps, li)
            acc = []
            steps[0..li].each do |s|
              case s[:kind]
              when :property_access
                acc << (acc.empty? ? [:input, s[:key].to_sym] : [:field, s[:key].to_sym])
              when :element_access
                # no hop
              when :array_loop
                break
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
              when :property_access
                keys << s[:key].to_sym
              when :element_access
                # no hop
              when :array_loop
                break
              end
            end
            keys
          end
        end
      end
    end
  end
end
