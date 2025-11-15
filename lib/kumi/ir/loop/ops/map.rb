# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Ops
        class Map < Node
          opcode :map

          def initialize(fn:, args:, **kwargs)
            attrs = { fn: fn.to_sym }
            super(inputs: Array(args), attributes: attrs, **kwargs)
          end

          def fn = attributes[:fn]
        end
      end
    end
  end
end
