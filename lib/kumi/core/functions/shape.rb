# frozen_string_literal: true

require_relative "dimension"

module Kumi
  module Core
    module Functions
      # Shape utilities with NEP 20 support. A "shape" is an Array<Dimension> of dimension objects.
      # [] == scalar, [Dimension.new(:i)] == vector along :i, etc.
      module Shape
        module_function

        def scalar?(shape) = shape.empty?

        def equal?(a, b) = a.map(&:name) == b.map(&:name)

        # NEP 20 broadcast rules:
        # - scalar can broadcast to any expected shape
        # - fixed-size dimensions must match exactly
        # - broadcastable dimensions with |1 modifier can broadcast against size-1
        # - flexible dimensions with ? can be omitted if not present in all operands
        def broadcastable?(got:, expected:)
          return true if scalar?(got)
          return false if got.length != expected.length

          got.zip(expected).all? do |got_dim, exp_dim|
            broadcastable_dimension?(got: got_dim, expected: exp_dim)
          end
        end

        def broadcastable_dimension?(got:, expected:)
          # Same name and modifiers
          return true if got == expected

          # Same name, different modifiers - check compatibility
          if got.name == expected.name
            # Fixed-size dimensions must match exactly
            if got.fixed_size? || expected.fixed_size?
              return got.size == expected.size if got.fixed_size? && expected.fixed_size?
              return false # one fixed, one not - incompatible
            end

            # Both named dimensions with same name are compatible
            return true
          end

          # Different names - only broadcastable with |1 modifier
          expected.broadcastable? && scalar?([got])
        end

        # Check if a dimension can be omitted (NEP 20 flexible dimensions)
        def flexible?(dim)
          dim.is_a?(Dimension) && dim.flexible?
        end

        # Check if a dimension can broadcast (NEP 20 broadcastable dimensions)
        def broadcastable_dimension?(dim)
          dim.is_a?(Dimension) && dim.broadcastable?
        end

        # Convenience: find dimensions in set a that are not in set b
        def dimensions_minus(a, b)
          a_names = a.map(&:name).to_set
          b_names = b.map(&:name).to_set
          (a_names - b_names).to_a
        end
      end
    end
  end
end
