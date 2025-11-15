# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Ops
        class ArrayBuild < Node
          opcode :array_build

          def initialize(result:, elements:, axes:, dtype:, metadata: {})
            super(result:, axes:, dtype:, inputs: Array(elements), attributes: {}, metadata:)
          end
        end

        class ArrayGet < Node
          opcode :array_get

          def initialize(result:, array:, index:, axes:, dtype:, oob:, metadata: {})
            attrs = { oob: oob.to_sym }
            super(result:, axes:, dtype:, inputs: [array, index], attributes: attrs, metadata:)
          end
        end

        class ArrayLen < Node
          opcode :array_len

          def initialize(result:, array:, axes:, dtype:, metadata: {})
            super(result:, axes:, dtype:, inputs: [array], metadata:, attributes: {})
          end
        end
      end
    end
  end
end
