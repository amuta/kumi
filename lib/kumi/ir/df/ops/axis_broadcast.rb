# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Ops
        class AxisBroadcast < Node
          opcode :axis_broadcast

          def initialize(value:, from_axes:, to_axes:, **kwargs)
            super(
              inputs: [value],
              attributes: {
                from_axes: Array(from_axes).map(&:to_sym),
                to_axes: Array(to_axes).map(&:to_sym)
              },
              **kwargs
            )
          end

          def value = inputs.first
          def from_axes = attributes[:from_axes]
          def to_axes = attributes[:to_axes]
        end
      end
    end
  end
end
