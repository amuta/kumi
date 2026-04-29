# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Ops
        class Node < Kumi::IR::Base::Instruction
          class << self
            attr_reader :opcode_symbol

            def opcode(value = nil)
              @opcode_symbol = value if value
              @opcode_symbol
            end
          end

          def initialize(result: nil, axes: [], dtype: nil, inputs: [], attributes: {}, metadata: {}, effects: Base::Effects::NONE)
            axes = Array(axes || []).map(&:to_sym).freeze
            merged_meta = metadata.merge(axes: axes)
            merged_meta = merged_meta.merge(dtype: dtype) if dtype
            super(
              opcode: self.class.opcode_symbol || infer_opcode,
              result: result,
              inputs: inputs,
              attributes: attributes,
              metadata: merged_meta,
              effects: effects
            )
          end

          def to_h
            super.merge(axes: axes, dtype: dtype)
          end

          private

          def infer_opcode
            name = self.class.name.split("::").last
            name.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.to_sym
          end
        end
      end
    end
  end
end
