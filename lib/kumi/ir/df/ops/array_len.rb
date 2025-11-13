# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Ops
        class ArrayLen < Node
          opcode :array_len

          def initialize(array:, **kwargs)
            super(
              inputs: [array],
              attributes: {},
              **kwargs
            )
          end

          def array = inputs.first
        end
      end
    end
  end
end
