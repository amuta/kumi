# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Ops
        class DeclRef < Node
          opcode :decl_ref

          def initialize(name:, **kwargs)
            super(
              inputs: [],
              attributes: { name: name.to_sym },
              **kwargs
            )
          end

          def declaration_name = attributes[:name]
        end
      end
    end
  end
end
