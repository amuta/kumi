# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Ops
        class AxisShift < Node
          opcode :axis_shift

          POLICIES = %i[wrap clamp zero].freeze

          def initialize(source:, axis:, offset:, policy:, **kwargs)
            policy = policy.to_sym
            raise ArgumentError, "invalid policy #{policy}" unless POLICIES.include?(policy)

            super(
              inputs: [source],
              attributes: {
                axis: axis.to_sym,
                offset: Integer(offset),
                policy: policy
              },
              **kwargs
            )
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
