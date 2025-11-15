# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Ops
        class MakeTuple < Node
          opcode :make_tuple

          def initialize(result:, elements:, axes:, dtype:, metadata: {})
            super(result:, axes:, dtype:, inputs: Array(elements), attributes: {}, metadata:)
          end
        end

        class MakeObject < Node
          opcode :make_object

          def initialize(result:, keys:, values:, axes:, dtype:, metadata: {})
            attributes = { keys: Array(keys).map(&:to_sym) }
            super(result:, axes:, dtype:, inputs: Array(values), attributes:, metadata:)
          end
        end

        class TupleGet < Node
          opcode :tuple_get

          def initialize(result:, tuple:, index:, axes:, dtype:, metadata: {})
            super(result:, axes:, dtype:, inputs: [tuple], attributes: { index: Integer(index) }, metadata:)
          end
        end
      end
    end
  end
end
