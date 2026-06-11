# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Ops
        class ArrayGet < Node
          OOB_POLICIES = %i[wrap clamp zero].freeze
          opcode :array_get

          def initialize(array:, index:, oob:, **kwargs)
            oob = oob.to_sym
            raise ArgumentError, "invalid oob policy #{oob}" unless OOB_POLICIES.include?(oob)

            super(
              inputs: [array, index],
              attributes: { oob: oob },
              **kwargs
            )
          end

          def array = inputs[0]
          def index = inputs[1]
          def oob_policy = attributes[:oob]
        end
      end
    end
  end
end
