# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Ops
        class LoadInput < Node
          opcode :load_input

          def initialize(key:, chain: [], source_plan: nil, **kwargs)
            attrs = {
              key: key.to_sym,
              chain: Array(chain).map(&:to_s)
            }
            attrs[:source_plan] = source_plan if source_plan
            super(
              inputs: [],
              attributes: attrs,
              **kwargs
            )
          end

          def key = attributes[:key]
          def chain = attributes[:chain]
        end
      end
    end
  end
end
