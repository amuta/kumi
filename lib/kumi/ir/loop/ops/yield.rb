# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Ops
        class Yield < Kumi::IR::Base::Instruction

          def initialize(values:, metadata: {})
            super(
              opcode: self.class.opcode_symbol,
              inputs: Array(values),
              metadata: metadata,
              effects: [Base::Effects::CONTROL]
            )
          end

          class << self
            attr_reader :opcode_symbol

            def opcode(value = nil)
              @opcode_symbol = value if value
              @opcode_symbol
            end
          end

          opcode :yield
        end
      end
    end
  end
end
