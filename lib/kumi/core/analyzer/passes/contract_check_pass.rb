# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class ContractCheckPass < PassBase
          REQUIRED_KEYS = %i[node_index decl_shapes scope_plans].freeze

          def run(errors)
            missing = REQUIRED_KEYS.reject { |k| state.key?(k) }
            unless missing.empty?
              errors << Core::ErrorReporter.create_error(
                "Analyzer contract violation: missing state #{missing.inspect}",
                location: nil,
                type: :developer
              )
              return state # Early return if required state is missing
            end

            # No vector guards in cascades: scope must be scalar when hierarchy invalid.
            node_index  = get_state(:node_index, required: false) || {}
            scope_plans = get_state(:scope_plans, required: false) || {}

            each_decl do |decl|
              next unless decl.expression.is_a?(Kumi::Syntax::CascadeExpression)
              
              plan = scope_plans[decl.name] || {}
              # If a pass tagged this cascade as scalarized, scope must be []
              if (node_index[decl.object_id] || {})[:cascade_scalarized]
                unless Array(plan[:scope]).empty?
                  errors << Core::ErrorReporter.create_error(
                    "Cascade `#{decl.name}` tagged scalarized but scope=#{plan[:scope].inspect}",
                    location: decl.loc,
                    type: :developer
                  )
                end
              end
            end

            # ---- NEW: per-call contract checks (must run AFTER planning) ----
            check_per_call_contracts!(node_index, errors)
            
            state
          end

          private

          def check_per_call_contracts!(node_index, errors)
            # Walk all CallExpression entries (consistent with CallNameNormalizePass approach)
            node_index.each_value do |entry|
              next unless entry.is_a?(Hash) && entry[:type] == "CallExpression"

              node = entry[:node]
              meta = entry

              # Skip special cascade_and desugaring markers (match LowerToIR behavior)
              next if node.fn_name == :cascade_and &&
                      (meta.dig(:metadata, :skip_signature) ||
                       meta.dig(:metadata, :desugar_to_identity) ||
                       meta.dig(:metadata, :desugar_to_chained_and) ||
                       meta.dig(:metadata, :invalid_cascade_and))

              validate_qualified_name(node, meta, errors)
              validate_selected_signature(node, meta, errors)
              validate_join_plan(node, meta, errors)

              # Optional: cheap rank sanity — if any arg has non-empty dims, signature must not be scalar-only
              # (We keep this conservative; the full correctness is already enforced during type/signature)
              # You can wire a stricter check later.
            end
          end

          def validate_qualified_name(node, meta, errors)
            qname = meta.dig(:metadata, :qualified_name)
            return if qname

            errors << Core::ErrorReporter.create_error(
              "Missing qualified_name for #{node.fn_name} (CallNameNormalizePass required)",
              location: node.respond_to?(:loc) ? node.loc : nil,
              type: :developer
            )
          end

          def validate_selected_signature(node, meta, errors)
            qname = meta.dig(:metadata, :qualified_name)
            return if meta.dig(:metadata, :selected_signature)

            errors << Core::ErrorReporter.create_error(
              "Missing selected_signature for #{qname}",
              location: node.respond_to?(:loc) ? node.loc : nil,
              type: :developer
            )
          end

          def validate_join_plan(node, meta, errors)
            qname = meta.dig(:metadata, :qualified_name)
            return if meta[:join_plan]

            errors << Core::ErrorReporter.create_error(
              "Missing join_plan for #{qname}",
              location: node.respond_to?(:loc) ? node.loc : nil,
              type: :developer
            )
          end
        end
      end
    end
  end
end
