# frozen_string_literal: true

module Kumi
  module Core
    module LIR
      # Peephole provides a small helper for implementing local LIR rewrites.
      # It iterates over an instruction array and yields a Window object that
      # exposes the current instruction alongside a handful of mutation helpers.
      #
      # Example:
      #   Peephole.run(ops) do |window|
      #     next unless window.match?(:Constant, :Constant, :KernelCall)
      #
      #     last = window.instruction(2)
      #     const = Build.constant(
      #       value: 3,
      #       dtype: last.stamp.dtype,
      #       as: last.result_register,
      #       ids: ids
      #     )
      #     window.replace(3, with: const)
      #   end
      class Peephole
        attr_reader :ops

        def self.run(ops, &)
          new(ops).run(&)
        end

        def initialize(ops)
          @ops = ops
        end

        def run
          index = 0
          while index < @ops.length
            window = Window.new(@ops, index)
            yield window
            index = window.next_index
          end
          @ops
        end

        # A mutable view over the instruction stream anchored at a given index.
        class Window
          attr_reader :index

          def initialize(ops, index)
            @ops = ops
            @index = index
            @next_index = index + 1
          end

          def current = instruction(0)

          def instruction(offset = 0)
            @ops[@index + offset]
          end

          def instructions(count)
            @ops[@index, count].compact
          end

          def match?(*opcodes)
            opcodes.each_with_index.all? do |opcode, off|
              ins = instruction(off)
              ins&.respond_to?(:opcode) && ins.opcode == opcode
            end
          end

          def const?(offset = 0, value: nil)
            ins = instruction(offset)
            return false unless ins&.opcode == :Constant

            return true if value.nil?

            literal_value(offset) == value
          end

          def zero?(offset = 0)
            const?(offset, value: 0)
          end

          def literal(offset = 0)
            ins = instruction(offset)
            Array(ins&.immediates).first
          end

          def literal_value(offset = 0)
            literal(offset)&.value
          end

          def replace(count, with:)
            replacements = normalize(with)
            @ops[@index, count] = replacements
            @next_index = @index
            replacements
          end

          def delete(count = 1)
            replace(count, with: [])
          end

          def insert_before(*new_ops)
            new_ops = normalize(new_ops)
            return @next_index = @index if new_ops.empty?

            @ops.insert(@index, *new_ops)
            @index += new_ops.length
            @next_index = @index
            new_ops
          end

          def insert_after(*new_ops)
            new_ops = normalize(new_ops)
            return @next_index = @index + 1 if new_ops.empty?

            @ops.insert(@index + 1, *new_ops)
            @next_index = @index + 1
            new_ops
          end

          def skip(count = 1)
            count = 1 if count.nil? || count < 1
            @next_index = @index + count
            nil
          end

          def rewind(count = 1)
            count = 1 if count.nil? || count < 1
            @next_index = [@index - count, 0].max
            nil
          end

          def next_index
            @next_index = 0 if @next_index.negative?
            @next_index = @ops.length if @next_index > @ops.length
            @next_index
          end

          def size
            @ops.length
          end

          private

          def normalize(value)
            if value.is_a?(Array)
              value.compact
            else
              value ? [value] : []
            end
          end
        end
      end
    end
  end
end
