# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Ops
        class Fold < Node
          opcode :fold

          def initialize(result:, fn:, arg:, axes:, dtype:, metadata: {})
            attrs = { fn: fn.to_sym }
            super(result:, axes:, dtype:, inputs: [arg], attributes: attrs, metadata:)
          end

          def fn = attributes[:fn]
        end
      end
    end
  end
end
