# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # AttachTerminalInfoPass
        # Reads state[:ir_input_plans]; writes fields onto NAST::InputRef nodes:
        # - @fqn                : String        (plan.path_fqn)
        # - @key_chain          : Array<Symbol> (property_access keys after last array_loop)
        # - @element_terminal   : Boolean       (true iff tail contains element_access)
        #
        # IMPORTANT: We derive terminal info solely from navigation_steps, not from
        # path tokens minus axes, to avoid conflating access path with iteration axes.
        class AttachTerminalInfoPass < PassBase
          NAST = Kumi::Core::NAST

          def run(_errors)
            plans = get_state(:ir_input_plans, required: true)
            by_fqn = plans.each_with_object({}) { |p, h| h[p.path_fqn.to_s] = p }

            mod = get_state(:snast_module, required: true)
            annotate!(mod, by_fqn)
            state
          end

          private

          def annotate!(node, by_fqn)
            case node
            when NAST::Module
              node.decls.each_value { annotate!(_1, by_fqn) }

            when NAST::Declaration
              annotate!(node.body, by_fqn)

            when NAST::InputRef
              plan = by_fqn.fetch(node.path_fqn.to_s)

              steps = Array(plan.navigation_steps)
              # find last array_loop in steps
              loop_indexes = steps.each_index.select { |i| steps[i][:kind].to_s == "array_loop" }
              *loops_idxs, last_loop_idx = loop_indexes
              b_last_loop_idx = loops_idxs.last || 0
              last_idx = steps.size - 1

              finish_at_loop = last_loop_idx == last_idx

              # If the last is not a loop, we cound from the last loop
              tail = steps[b_last_loop_idx..last_idx] if finish_at_loop
              tail ||= steps[last_loop_idx..last_idx]

              # property keys after the last loop
              keys = tail.select { |s| s[:kind] == "property_access" }
                         .map { |s| s[:key].to_sym }

              # element access present in the tail?
              element = tail.any? { |s| s[:kind].to_s == "element_access" }

              # TODO: See a beter way...
              keys << tail.last[:key].to_sym if tail.last[:key] && finish_at_loop && !element

              # sanity: no property access after element access
              raise "invalid plan: property_access after element_access for #{plan.path_fqn}" if element && keys.any?

              node.instance_variable_set(:@fqn, plan.path_fqn.to_s)
              node.instance_variable_set(:@key_chain, keys)
              node.instance_variable_set(:@element_terminal, element)

            when NAST::Tuple, NAST::Call
              node.args.each { annotate!(_1, by_fqn) }
            when NAST::Hash
              node.pairs.each { annotate!(_1.value, by_fqn) }
            when NAST::Pair
              annotate!(node.value, by_fqn)
            when NAST::Select
              annotate!(node.cond, by_fqn)
              annotate!(node.on_true, by_fqn)
              annotate!(node.on_false, by_fqn)
            when NAST::Reduce, NAST::Fold
              annotate!(node.arg, by_fqn)
            end
          end
        end
      end
    end
  end
end
