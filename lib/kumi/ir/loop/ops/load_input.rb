# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Ops
        class LoadInput < Node
          opcode :load_input

          def initialize(key:, plan_ref:, chain: [], **kwargs)
            attrs = {
              key: key.to_sym,
              chain: Array(chain).map(&:to_s),
              plan_ref: plan_ref
            }
            super(inputs: [], attributes: attrs, **kwargs)
          end

          def key = attributes[:key]
          def plan_ref = attributes[:plan_ref]
          def chain = attributes[:chain]
        end
      end
    end
  end
end
