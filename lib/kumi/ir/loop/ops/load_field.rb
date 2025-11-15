# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Ops
        class LoadField < Node
          opcode :load_field

          def initialize(object:, field:, plan_ref:, **kwargs)
            attrs = {
              field: field.to_sym,
              plan_ref: plan_ref
            }
            super(inputs: [object], attributes: attrs, **kwargs)
          end

          def field = attributes[:field]
          def plan_ref = attributes[:plan_ref]
          def object = inputs.first
        end
      end
    end
  end
end
