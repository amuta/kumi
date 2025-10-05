# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # AttachTerminalInfoPass
        # Reads state[:input_table]; writes onto NAST::InputRef:
        # - @fqn               : String
        # - @key_chain         : Array<Symbol>   (property keys after last array loop)
        # - @element_terminal  : Boolean         (tail includes element_access)
        class AttachTerminalInfoPass < PassBase
          NAST = Kumi::Core::NAST

          def run(_errors)
            plans = get_state(:input_table, required: true) # Array of InputPlan
            by_fqn = plans.each_with_object({}) { |p, h| h[p.path_fqn.to_s] = p }
            mod = get_state(:snast_module, required: true)
            annotate!(mod, by_fqn)
            state
          end

          private

          def annotate!(node, by_fqn)
            case node
            when NAST::Module
              node.decls.each_value { |d| annotate!(d, by_fqn) }

            when NAST::Declaration
              annotate!(node.body, by_fqn)

            when NAST::InputRef
              plan = by_fqn.fetch(node.path_fqn.to_s) do
                raise KeyError, "No InputPlan for #{node.path_fqn.inspect}"
              end
              steps = Array(plan.navigation_steps)

              # last array loop (or -1 if none)
              last_loop_idx = steps.rindex { |s| (s[:kind] || s["kind"]).to_s == "array_loop" } || -1
              tail = steps[(last_loop_idx + 1)..-1] || []

              # detect element access in tail
              elem_idx = tail.index { |s| (s[:kind] || s["kind"]).to_s == "element_access" }
              element_terminal = !elem_idx.nil?

              # ensure no property_access after element_access
              # if element_terminal
              #   binding.pry
              #   bad = tail[(elem_idx + 1)..-1].to_a.any? { |s| (s[:kind] || s["kind"]).to_s == "property_access" }
              #   raise "invalid plan: property_access after element_access for #{plan.path_fqn}" if bad
              # end

              # collect keys after last loop (only property_access, stop before element_access if present)
              key_chain = tail
                          .select { |s| (s[:kind] || s["kind"]).to_s == "property_access" }
                          .map    { |s| (s[:key]  || s["key"]).to_sym }

              node.instance_variable_set(:@fqn, plan.path_fqn.to_s)
              node.instance_variable_set(:@key_chain, key_chain)
              node.instance_variable_set(:@element_terminal, element_terminal)

            when NAST::Tuple, NAST::Call
              node.args.each { |a| annotate!(a, by_fqn) }

            when NAST::Hash
              node.pairs.each { |p| annotate!(p.value, by_fqn) }

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
