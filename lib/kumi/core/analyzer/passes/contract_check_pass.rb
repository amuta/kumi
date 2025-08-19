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
            
            state
          end
        end
      end
    end
  end
end