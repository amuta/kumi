# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Ops
        class Node < Kumi::IR::Base::Instruction
          class << self
            attr_reader :opcode_symbol

            def opcode(value = nil)
              @opcode_symbol = value if value
              @opcode_symbol
            end
          end

          def initialize(result:, axes:, dtype:, inputs: [], attributes: {}, metadata: {}, effects: Base::Effects::NONE)
            raise ArgumentError, "dtype required" unless dtype

            axes = Array(axes || []).map(&:to_sym).freeze
            metadata = metadata.merge(dtype: dtype, axes:)
            super(
              opcode: self.class.opcode_symbol || infer_opcode,
              result: result,
              inputs:,
              attributes: attributes,
              metadata: metadata,
              effects:
            )
          end

          def to_h
            super.merge(axes:, dtype:)
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
