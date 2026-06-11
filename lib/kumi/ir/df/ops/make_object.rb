# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Ops
        class MakeObject < Node
          opcode :make_object

          def initialize(inputs:, keys:, **kwargs)
            super(
              inputs: Array(inputs),
              attributes: { keys: Array(keys).map(&:to_sym) },
              **kwargs
            )
          end

          def keys = attributes[:keys]
        end
      end
    end
  end
end
