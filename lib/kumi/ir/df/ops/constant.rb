# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Ops
        class Constant < Node
          opcode :constant

          def initialize(value:, **kwargs)
            super(
              inputs: [],
              attributes: { value: value },
              **kwargs
            )
          end
        end
      end
    end
  end
end
