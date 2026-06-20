# frozen_string_literal: true

module Kumi
  module IR
    module Base
      class Function
        attr_reader :name, :parameters, :blocks

        def initialize(name:, parameters: [], blocks: [])
          @name = name.to_sym
          @parameters = parameters.map(&:to_sym)
          @blocks = blocks.map { |b| ensure_block(b) }
        end

        def entry_block
          @blocks.first
        end

        def append_block(block)
          @blocks << ensure_block(block)
        end

        def to_h
          {
            name:,
            parameters:,
            blocks: @blocks.map { |b| { name: b.name, instructions: b.instructions.map(&:to_h) } }
          }
        end

        private

        def ensure_block(block)
          case block
          when Block then block
          else
            raise ArgumentError, "expected Block, got #{block.class}"
          end
        end
      end
    end
  end
end
