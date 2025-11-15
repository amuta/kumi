# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Ops
        class Select < Node
          opcode :select

          def initialize(cond:, on_true:, on_false:, **kwargs)
            super(inputs: [cond, on_true, on_false], **kwargs)
          end

          def cond = inputs[0]
          def on_true = inputs[1]
          def on_false = inputs[2]
        end
      end
    end
  end
end
