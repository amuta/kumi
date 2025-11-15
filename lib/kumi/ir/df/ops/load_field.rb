# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Ops
        class LoadField < Node
          opcode :load_field

          def initialize(object:, field:, plan_ref: nil, **kwargs)
            super(
              inputs: [object],
              attributes: build_attrs(field, plan_ref),
              **kwargs
            )
          end

          def object = inputs.first
          def field = attributes[:field]
          def plan_ref = attributes[:plan_ref]

          private

          def build_attrs(field, plan_ref)
            attrs = { field: field.to_sym }
            attrs[:plan_ref] = plan_ref if plan_ref
            attrs
          end
        end
      end
    end
  end
end
