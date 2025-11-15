# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Ops
        class AxisBroadcast < Node
          opcode :axis_broadcast

          def initialize(result:, value:, from_axes:, to_axes:, axes:, dtype:, metadata: {})
            attrs = {
              from_axes: Array(from_axes).map(&:to_sym),
              to_axes: Array(to_axes).map(&:to_sym)
            }
            super(result:, axes:, dtype:, inputs: [value], attributes: attrs, metadata:)
          end

          def from_axes = attributes[:from_axes]
          def to_axes = attributes[:to_axes]
        end
      end
    end
  end
end
