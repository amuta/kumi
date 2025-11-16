# frozen_string_literal: true

module Kumi
  module IR
    module Vec
      class Validator
        ALLOWED_OPS = %i[
          constant
          load_input
          load_field
          map
          select
          axis_broadcast
          axis_shift
          axis_index
          reduce
        ].freeze

        def self.validate!(vec_module)
          new(vec_module).validate!
          vec_module
        end

        def initialize(vec_module)
          @vec_module = vec_module
        end

        def validate!
          vec_module.each_function { |fn| validate_function(fn) }
        end

        private

        attr_reader :vec_module

        def validate_function(function)
          function.blocks.each do |block|
            block.instructions.each { |instr| validate_instruction(instr) }
          end
        end

        def validate_instruction(instr)
          unless ALLOWED_OPS.include?(instr.opcode)
            raise ArgumentError, "VecIR does not support opcode #{instr.opcode}"
          end

          dtype = instr.metadata[:dtype] || instr.dtype
          if dtype.respond_to?(:element_types)
            raise ArgumentError, "VecIR disallows tuple dtype (#{dtype})"
          end

          return unless instr.opcode == :axis_broadcast

          expected = Array(instr.attributes[:to_axes]).map(&:to_sym)
          raise ArgumentError, "AxisBroadcast axes mismatch" unless Array(instr.axes) == expected
        end
      end
    end
  end
end
