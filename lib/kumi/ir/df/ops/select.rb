# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Ops
        class Select < Node
          opcode :select

          def initialize(cond:, on_true:, on_false:, **kwargs)
            super(
              inputs: [cond, on_true, on_false],
              attributes: {},
              **kwargs
            )
          end

          def condition = inputs[0]
          def true_value = inputs[1]
          def false_value = inputs[2]
        end
      end
    end
  end
end
