# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Ops
        class Map < Node
          opcode :map

          def initialize(fn:, args:, **kwargs)
            super(
              inputs: Array(args),
              attributes: { fn: fn.to_sym },
              **kwargs
            )
          end
        end
      end
    end
  end
end
