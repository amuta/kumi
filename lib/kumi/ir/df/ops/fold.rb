# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Ops
        class Fold < Node
          opcode :fold

          def initialize(fn:, arg:, **kwargs)
            super(
              inputs: [arg],
              attributes: { fn: fn.to_sym },
              **kwargs
            )
          end
        end
      end
    end
  end
end
