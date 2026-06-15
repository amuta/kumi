# frozen_string_literal: true

module Kumi
  module TestSharedSchemas
    # Uses `cross` internally so imports of this schema exercise cross-axis
    # survival through DFIR import inlining (the callee mints a `__x` axis the
    # caller never analyzed).
    module Pairwise
      extend Kumi::Schema

      schema do
        input do
          array :vals, index: :v do
            hash :v do
              float :a
            end
          end
        end

        let :ai, input.vals.v.a
        let :aj, cross(input.vals.v.a)
        # Per element i: sum over all j of (a_j - a_i).
        value :pairsum, fn(:sum, aj - ai)
      end
    end
  end
end
