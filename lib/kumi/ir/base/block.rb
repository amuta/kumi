# frozen_string_literal: true

module Kumi
  module IR
    module Base
      class Block
        include Enumerable

        attr_reader :name, :instructions

        def initialize(name:, instructions: [])
          @name = name.to_sym
          @instructions = instructions.dup
        end

        def each(&)
          @instructions.each(&)
        end

        def append(instr)
          raise ArgumentError, "instruction required" unless instr.is_a?(Instruction)

          @instructions << instr
          instr
        end

        def empty?
          @instructions.empty?
        end

        # The block's last result-bearing instruction. By the IR convention this
        # is the function's result, so passes that drop/dedup instructions use it
        # to avoid collapsing the terminal (which would change what the function
        # returns). nil for a block that defines no value.
        def terminal_instruction
          @instructions.reverse_each.find { |instr| instr.defs.first }
        end
      end
    end
  end
end
