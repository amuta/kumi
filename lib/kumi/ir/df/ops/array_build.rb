# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Ops
        class ArrayBuild < Node
          opcode :array_build

          def initialize(elements:, **kwargs)
            super(
              inputs: Array(elements),
              attributes: { size: Array(elements).size },
              **kwargs
            )
          end

          def size = attributes[:size]
        end
      end
    end
  end
end
