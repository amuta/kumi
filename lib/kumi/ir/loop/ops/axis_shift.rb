# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Ops
        class AxisShift < Node
          opcode :axis_shift

          POLICIES = %i[wrap clamp zero].freeze

          def initialize(result:, source:, axis:, offset:, policy:, axes:, dtype:, metadata: {})
            policy = policy.to_sym
            raise ArgumentError, "invalid policy #{policy}" unless POLICIES.include?(policy)

            attrs = {
              axis: axis.to_sym,
              offset: Integer(offset),
              policy:
            }
            super(result:, axes:, dtype:, inputs: [source], attributes: attrs, metadata:)
          end

          def source = inputs.first
          def axis = attributes[:axis]
          def offset = attributes[:offset]
          def policy = attributes[:policy]
        end
      end
    end
  end
end
