# frozen_string_literal: true

require "json"

module Kumi
  module Core
    module Analyzer
      module Passes
        # AttachTerminalInfoPass with debug tracing
        class AttachTerminalInfoPass < PassBase
          NAST = Kumi::Core::NAST

          def run(_errors)
            @dbg = ENV["KUMI_DEBUG_TERMINAL"] == "1"
            plans  = get_state(:input_table, required: true) # Array<InputPlan>
            by_fqn = plans.each_with_object({}) { |p, h| h[p.path_fqn.to_s] = p }
            mod    = get_state(:snast_module, required: true)
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
              annotate_input_ref!(node, by_fqn)
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
            when NAST::IndexRef
              # no-op
            end
          end

          def annotate_input_ref!(node, by_fqn)
            plan  = by_fqn.fetch(node.path_fqn.to_s) { raise KeyError, "No InputPlan for #{node.path_fqn.inspect}" }
            steps = normalize_steps(plan.navigation_steps) # do not mutate original

            # Compute from original steps
            base_sym, full_chain = detect_base_and_full_chain(steps)
            tail = tail_after_last_loop(steps)
            element_terminal = tail.any? { |s| s[:kind] == "element_access" }

            # Compute key_chain based on context
            key_chain =
              if !element_terminal && tail.empty? && !full_chain.empty?
                # Non-element-terminal array reference (e.g., fn(:array_size, input.x))
                # Use full property chain to load from root
                full_chain
              else
                # Element access or other cases: collect from tail
                collect_tail_props(tail)
              end

            # Attach
            node.instance_variable_set(:@fqn,               plan.path_fqn.to_s)
            node.instance_variable_set(:@base_sym,          base_sym)
            node.instance_variable_set(:@base_is_root,      base_sym == :__root)
            node.instance_variable_set(:@full_chain,        full_chain)
            node.instance_variable_set(:@key_chain,         key_chain)
            node.instance_variable_set(:@element_terminal,  element_terminal)

            return unless debug_enabled?

            dbg_dump(
              title: "InputRef #{plan.path_fqn}",
              open_axis: plan.respond_to?(:open_axis) ? plan.open_axis : nil,
              steps: steps,
              tail: tail,
              base_sym: base_sym,
              full_chain: full_chain,
              key_chain: key_chain,
              element_terminal: element_terminal
            )
          end

          # ---------- helpers ----------

          def normalize_steps(raw)
            Array(raw).map do |s|
              { kind: (s[:kind] || s["kind"]).to_s, key: s[:key] || s["key"] }
            end
          end

          def array_loop?(s)      = s && s[:kind] == "array_loop"
          def property_access?(s) = s && s[:kind] == "property_access"
          def element_access?(s)  = s && s[:kind] == "element_access"

          # base + full property chain
          def detect_base_and_full_chain(steps)
            return [:__root, []] if steps.empty?

            first_loop_idx = steps.index { |s| array_loop?(s) } || steps.length
            pre            = steps[0...first_loop_idx]

            base_sym =
              if property_access?(pre.first)
                pre.first[:key].to_sym
              else
                :__root
              end

            props = steps.select { |s| property_access?(s) }.map { |s| s[:key].to_sym }
            props = [base_sym] + props if base_sym != :__root && props.first != base_sym
            [base_sym, props]
          end

          # steps strictly after the last array_loop; if none, the entire steps
          def tail_after_last_loop(steps)
            last_loop_idx = steps.rindex { |s| array_loop?(s) } || -1
            steps[(last_loop_idx + 1)..-1] || []
          end

          # property_access keys in tail:
          # - if an element_access exists, collect properties AFTER the first element_access
          # - otherwise collect all property_access in tail
          def collect_tail_props(tail)
            elem_idx = tail.index { |s| s && s[:kind] == "element_access" }

            range =
              if elem_idx
                (elem_idx + 1)..-1       # after the element access
              else
                0..-1                    # no element access, take all
              end

            tail[range].to_a
                       .select { |s| s[:kind] == "property_access" }
                       .map    { |s| s[:key].to_sym }
          end

          # pretty trace
          def dbg_dump(title:, open_axis:, steps:, tail:, base_sym:, full_chain:, key_chain:, element_terminal:)
            puts "[AttachTerminalInfo] #{title}"
            puts "  open_axis: #{open_axis.inspect}"
            puts "  steps:"
            steps.each_with_index { |s, i| puts "    #{i}: #{fmt_step(s)}" }
            puts "  tail:"
            tail.each_with_index { |s, i| puts "    #{i}: #{fmt_step(s)}" }
            puts "  base_sym: #{base_sym.inspect}"
            puts "  full_chain: #{full_chain.inspect}"
            puts "  key_chain: #{key_chain.inspect}"
            puts "  element_terminal: #{element_terminal}"
            # quick sanity checks
            if key_chain.empty? && steps.any? { |s| property_access?(s) } && !element_terminal
              puts "  WARN: tail lost property keys? check last array_loop split"
            end
            if element_terminal && !steps.any? { |s| element_access?(s) }
              puts "  WARN: element_terminal=true but no element_access in steps"
            end
            puts
          end

          def fmt_step(s)
            k = s[:kind]
            case k
            when "property_access" then "property_access(#{s[:key].inspect})"
            when "element_access"  then "element_access"
            when "array_loop"      then "array_loop(#{s[:key].inspect})"
            else                        "#{k}(#{s[:key].inspect})"
            end
          end
        end
      end
    end
  end
end
