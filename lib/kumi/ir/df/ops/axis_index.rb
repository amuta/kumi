# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Ops
        class AxisIndex < Node
          opcode :axis_index

          def initialize(axis:, **kwargs)
            super(
              inputs: [],
              attributes: { axis: axis.to_sym },
              **kwargs
            )
          end

          def axis = attributes[:axis]
        end
      end
    end
  end
end
