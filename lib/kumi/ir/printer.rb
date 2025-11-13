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
            io.puts "  block #{block.name}:"
            block.each do |instr|
              io.puts "    #{instr.to_print_string(self)}"
            end
          end
        end
      end

      private

      attr_reader :ir_module, :io
    end
  end
end
