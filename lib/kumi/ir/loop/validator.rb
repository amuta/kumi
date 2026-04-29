# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      class Validator
        ALLOWED_OPS = %i[
          constant
          load_input
          load_field
          kernel_call
          select
          make_object
          reduce
        ].freeze

        def self.validate!(loop_module)
          new(loop_module).validate!
          loop_module
        end

        def initialize(loop_module)
          @loop_module = loop_module
        end

        def validate!
          loop_module.each_function { |fn| validate_function(fn) }
        end

        private

        attr_reader :loop_module

        def validate_function(function)
          raise ArgumentError, "LoopIR function missing return_reg" unless function.return_reg

          function.blocks.each do |block|
            defs = {}
            block.instructions.each do |instr|
              defs[instr.result] = instr if instr.result
              validate_instruction(instr, defs)
            end
          end
        end

        def validate_instruction(instr, defs)
          raise ArgumentError, "LoopIR does not support opcode #{instr.opcode}" unless ALLOWED_OPS.include?(instr.opcode)

          case instr.opcode
          when :load_field
            source = defs[instr.inputs.first]
            if source && Array(source.axes) != Array(instr.axes)
              raise ArgumentError, "LoopIR load_field must preserve axes"
            end
          when :select
            raise ArgumentError, "LoopIR select expects 3 inputs" unless instr.inputs.size == 3
          when :make_object
            keys = Array(instr.attributes[:keys])
            raise ArgumentError, "LoopIR make_object inputs/keys mismatch" unless keys.size == instr.inputs.size
          when :reduce
            over_axes = Array(instr.attributes[:over_axes]).map(&:to_sym)
            raise ArgumentError, "LoopIR reduce missing over_axes" if over_axes.empty?
          end
        end
      end
    end
  end
end
