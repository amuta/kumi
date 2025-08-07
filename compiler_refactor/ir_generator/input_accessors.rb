# frozen_string_literal: true

module Kumi
  module Core
    module IRGeneratorModules
      # Handles accessor generation for input paths
      module InputAccessors
        private

        def generate_accessors
          # Use the existing AccessorPlanner and AccessorBuilder
          input_metadata = @state[:inputs] || {}
          access_plans = Core::Compiler::AccessorPlanner.plan(input_metadata)
          built_accessors = Core::Compiler::AccessorBuilder.build(access_plans)
          
          # Return the built accessors directly - they're keyed as "path:mode"
          built_accessors
        end

        def build_accessor_key(path, mode)
          "#{path.join('.')}:#{mode}"
        end
      end
    end
  end
end