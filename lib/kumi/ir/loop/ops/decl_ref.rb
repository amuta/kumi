# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Ops
        class DeclRef < Node
          opcode :decl_ref

          def initialize(name:, axes:, dtype:, result:, metadata: {})
            super(result:, axes:, dtype:, attributes: { name: name.to_sym }, metadata:)
          end

          def name = attributes[:name]
        end
      end
    end
  end
end
