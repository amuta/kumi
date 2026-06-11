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

        def each(&block)
          @instructions.each(&block)
        end

        def append(instr)
          raise ArgumentError, "instruction required" unless instr.is_a?(Instruction)
          @instructions << instr
          instr
        end

        def empty?
          @instructions.empty?
        end
      end
    end
  end
end
