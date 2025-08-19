# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module LowerToIR
          module Contracts
            def require_call_contract!(node_index, call, errors)
              meta = node_index[call.object_id] || {}
              
              # Skip validation for cascade_and nodes that are marked for desugar or skip_signature
              if call.fn_name == :cascade_and && 
                 (meta.dig(:metadata, :skip_signature) || 
                  meta.dig(:metadata, :desugar_to_identity) ||
                  meta.dig(:metadata, :desugar_to_chained_and) ||
                  meta.dig(:metadata, :invalid_cascade_and))
                # These nodes will be handled specially during compilation
                return meta
              end
              
              qualified_name = meta.dig(:metadata, :qualified_name)
              
              unless qualified_name
                errors << Core::ErrorReporter.create_error(
                  "Missing qualified_name for #{call.fn_name} (CallNameNormalizePass required)",
                  location: call.respond_to?(:loc) ? call.loc : nil,
                  type: :developer
                )
                return nil
              end
              
              unless meta.dig(:metadata, :selected_signature)
                errors << Core::ErrorReporter.create_error(
                  "Missing selected_signature for #{qualified_name}",
                  location: call.respond_to?(:loc) ? call.loc : nil,
                  type: :developer
                )
                return nil
              end
              
              unless meta[:join_plan]
                errors << Core::ErrorReporter.create_error(
                  "Missing join_plan for #{qualified_name}",
                  location: call.respond_to?(:loc) ? call.loc : nil,
                  type: :developer
                )
                return nil
              end
              
              meta
            end

            def require_scalar_cascade!(decl_name, scope_plans, errors)
              scope = Array(scope_plans.dig(decl_name, :scope))
              unless scope.empty?
                errors << Core::ErrorReporter.create_error(
                  "Vector cascades must be scalarized upstream (#{decl_name})",
                  location: nil,
                  type: :developer
                )
                return false
              end
              true
            end
          end
        end
      end
    end
  end
end