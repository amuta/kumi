# frozen_string_literal: true

module Kumi
  module Core
    module IRGeneratorModules
      # Handles type coordination between inferencer and broadcast detector
      module TypeResolver
        private

        # Coordinate type inferencer output with broadcast detector metadata
        def coordinate_type(base_type, operation_type, metadata)
          case operation_type
          when :element_wise
            # Upgrade scalar type to array type based on element-wise strategy
            { array: base_type }
          when :reduction
            # Reduction operations: array input -> scalar output (keep base_type)
            base_type
          else
            # Scalar operations: keep base type
            base_type
          end
        end
      end
    end
  end
end