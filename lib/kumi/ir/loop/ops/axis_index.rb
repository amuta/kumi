# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Ops
        class AxisIndex < Node
          opcode :axis_index

          def initialize(result:, axis:, axes:, dtype:, metadata: {})
            attrs = { axis: axis.to_sym }
            super(result:, axes:, dtype:, inputs: [], attributes: attrs, metadata:)
          end

          def axis = attributes[:axis]
        end
      end
    end
  end
end
