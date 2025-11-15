# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Ops
        class Constant < Node
          opcode :constant

          def initialize(value:, **kwargs)
            super(attributes: { value: }.merge(kwargs.fetch(:attributes, {})), **kwargs)
          end

          def value = attributes[:value]
        end
      end
    end
  end
end
