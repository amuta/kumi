# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Ops
        # Re-exposes `source` (an array over `source_axis`) under a fresh,
        # independent axis `axis` backed by the same carrier. The result has the
        # source's axes plus `axis` appended as the new innermost axis, so the
        # element at (i, j) reads source[j]. This is the broadcast-dual of a
        # reduction and is what makes all-pairs / self-join computations
        # (e.g. N-body) expressible.
        class AxisCross < Node
          opcode :axis_cross

          def initialize(source:, axis:, source_axis:, **kwargs)
            super(
              inputs: [source],
              attributes: {
                axis: axis.to_sym,
                source_axis: source_axis.to_sym
              },
              **kwargs
            )
          end

          def source = inputs.first
          def axis = attributes[:axis]
          def source_axis = attributes[:source_axis]
        end
      end
    end
  end
end
