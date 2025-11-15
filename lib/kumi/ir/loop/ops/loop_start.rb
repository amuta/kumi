# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Ops
        class LoopStart < Kumi::IR::Base::Instruction

          def initialize(collection:, axis:, element:, index:, loop_id:, metadata: {})
            attrs = {
              axis: axis.to_sym,
              element: element,
              index: index,
              loop_id: loop_id
            }
            super(
              opcode: self.class.opcode_symbol,
              inputs: [collection],
              attributes: attrs,
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

          opcode :loop_start
        end
      end
    end
  end
end
