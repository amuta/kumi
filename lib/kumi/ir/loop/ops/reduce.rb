# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Ops
        class DeclareAccumulator < Kumi::IR::Loop::Instruction

          def initialize(result:, fn:, axes:, dtype:, metadata: {})
            metadata = metadata.merge(axes: Array(axes).map(&:to_sym), dtype:)
            super(
              opcode: self.class.opcode_symbol,
              result: result,
              attributes: { fn: fn.to_sym },
              metadata: metadata,
              effects: [Base::Effects::STATE]
            )
          end

          class << self
            attr_reader :opcode_symbol

            def opcode(value = nil)
              @opcode_symbol = value if value
              @opcode_symbol
            end
          end

          opcode :declare_accumulator
        end

        class Accumulate < Kumi::IR::Loop::Instruction

          def initialize(accumulator:, value:, metadata: {})
            super(
              opcode: self.class.opcode_symbol,
              inputs: [accumulator, value],
              metadata: metadata,
              effects: [Base::Effects::STATE]
            )
          end

          class << self
            attr_reader :opcode_symbol

            def opcode(value = nil)
              @opcode_symbol = value if value
              @opcode_symbol
            end
          end

          opcode :accumulate
        end

        class LoadAccumulator < Node
          opcode :load_accumulator

          def initialize(accumulator:, **kwargs)
            super(inputs: [accumulator], **kwargs)
          end
        end
      end
    end
  end
end
