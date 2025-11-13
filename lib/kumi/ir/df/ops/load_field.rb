# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Ops
        class LoadField < Node
          opcode :load_field

          def initialize(object:, field:, **kwargs)
            super(
              inputs: [object],
              attributes: { field: field.to_sym },
              **kwargs
            )
          end

          def object = inputs.first
          def field = attributes[:field]
        end
      end
    end
  end
end
