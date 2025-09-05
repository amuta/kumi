# frozen_string_literal: true

# Zeitwerk: Kumi::Codegen::RubyV3::CGIR

module Kumi
  module Codegen
    module RubyV3
      module CGIR
        Function = Struct.new(:name, :rank, :ops, keyword_init: true)

        module Op
          def self.open_loop(depth:, step_kind:, key: nil, phase: :pre)
            { k: :OpenLoop, depth:, step_kind:, key:, phase: }
          end

          def self.acc_reset(name:, depth:, init:, phase: :pre)
            { k: :AccReset, name:, depth:, init:, phase: }
          end

          def self.acc_add(name:, expr:, depth:, phase: :body)
            { k: :AccAdd, name:, expr:, depth:, phase: }
          end

          def self.emit(code:, depth:, op_type: nil, sort_after: nil, phase: :body)
            result = { k: :Emit, code:, depth:, phase: }
            result[:op_type] = op_type if op_type
            result[:sort_after] = sort_after if sort_after
            result
          end

          def self.yield(expr:, indices:, depth:, sort_after: nil, phase: :post)
            result = { k: :Yield, expr:, indices:, depth:, phase: }
            result[:sort_after] = sort_after if sort_after
            result
          end

          def self.close_loop(depth:, phase: :post)
            { k: :CloseLoop, depth:, phase: }
          end
        end
      end
    end
  end
end
