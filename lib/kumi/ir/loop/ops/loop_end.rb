# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Ops
        class LoopEnd < Kumi::IR::Base::Instruction

          def initialize(loop_id:, metadata: {})
            super(
              opcode: self.class.opcode_symbol,
              inputs: [],
              attributes: { loop_id: loop_id },
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

          opcode :loop_end
        end
      end
    end
  end
end
