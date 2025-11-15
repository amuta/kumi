# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Ops
        class LoadInput < Node
          opcode :load_input

          def initialize(key:, chain: [], source_plan: nil, plan_ref: nil, **kwargs)
            attrs = {
              key: key.to_sym,
              chain: Array(chain).map(&:to_s)
            }
            attrs[:source_plan] = source_plan if source_plan
            attrs[:plan_ref] = plan_ref if plan_ref
            super(
              inputs: [],
              attributes: attrs,
              **kwargs
            )
          end

          def key = attributes[:key]
          def chain = attributes[:chain]
          def plan_ref = attributes[:plan_ref]
        end
      end
    end
  end
end
