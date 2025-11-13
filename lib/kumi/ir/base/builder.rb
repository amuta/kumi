# frozen_string_literal: true

module Kumi
  module IR
    module Base
      class Builder
        attr_reader :ir_module, :function, :current_block

        def initialize(ir_module:, function:)
          @ir_module = ir_module
          @function = function
          @current_block = function.entry_block
        end

        def set_block(block)
          @current_block = block
        end

        def new_block(name)
          block = Block.new(name:)
          function.append_block(block)
          block
        end

        def emit(opcode, **kwargs)
          ensure_block!
          instr = instruction_class.new(**{ opcode: }.merge(kwargs))
          @current_block.append(instr)
        end

        private

        def ensure_block!
          raise "no active block" unless @current_block
        end

        def instruction_class
          Instruction
        end
      end
    end
  end
end
