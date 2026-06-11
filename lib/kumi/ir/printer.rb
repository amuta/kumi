# frozen_string_literal: true

module Kumi
  module IR
    class Printer
      def self.print(ir_module, io: $stdout)
        new(ir_module, io).print
      end

      def initialize(ir_module, io)
        @ir_module = ir_module
        @io = io
      end

      def print
        ir_module.each_function do |fn|
          io.puts "function #{fn.name}:"
          fn.blocks.each do |block|
            print_block(block)
          end
        end
      end

      private

      attr_reader :ir_module, :io

      def print_block(block)
        loop_depth = 0

        block.each do |instr|
          loop_depth -= 1 if closes_loop?(instr)
          loop_depth = 0 if loop_depth.negative?

          io.puts(indent_for(loop_depth) + instr.to_print_string(self))

          loop_depth += 1 if opens_loop?(instr)
        end
      end

      def indent_for(loop_depth)
        "  " + ("  " * loop_depth)
      end

      def opens_loop?(instr)
        instr.respond_to?(:opcode) && instr.opcode == :loop_start
      end

      def closes_loop?(instr)
        instr.respond_to?(:opcode) && instr.opcode == :loop_end
      end
    end
  end
end
