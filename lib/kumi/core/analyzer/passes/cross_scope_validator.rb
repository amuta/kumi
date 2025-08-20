# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Validate cross-scope operations and enforce join requirements  
        # DEPENDENCIES: :broadcasts, :declarations
        #
        # PRODUCES:
        #   - Validation errors for unsupported cross-scope operations without join support
        #
        # VALIDATION RULES:
        #   - Cross-scope vectorized operations must have explicit join support
        #   - Operations spanning different array scopes require join planning
        #   - Ensures dimensional consistency across scope boundaries
        class CrossScopeValidator < PassBase
          def run(errors)
            broadcasts = get_state(:broadcasts)
            declarations = get_state(:declarations)

            return state unless broadcasts

            # Check vectorized operations for cross-scope operations
            vectorized_ops = broadcasts[:vectorized_operations] || {}
            vectorized_ops.each do |name, broadcast_info|
              next unless broadcast_info.is_a?(Hash)
              next unless broadcast_info[:cross_scope]

              # This is a cross-scope operation that requires join support
              if broadcast_info[:requires_join]
                sources = broadcast_info[:sources] || []
                decl = declarations[name]
                
                add_error(errors, nil, 
                         "cross-scope map without join: #{sources.inspect}. " \
                         "Operations across different array scopes require explicit join support, " \
                         "which is not yet implemented.")
              end
            end

            state
          end
        end
      end
    end
  end
end