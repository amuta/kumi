# frozen_string_literal: true

module Kumi
  module IR
    module DF
      class Validator
        ALLOWED_OPS = %i[
          constant
          load_input
          load_field
          map
          select
          reduce
          decl_ref
          make_object
          array_build
          array_get
          array_len
          axis_index
          import_call
          axis_shift
          axis_broadcast
        ].freeze

        def self.validate!(df_module)
          new(df_module).validate!
          df_module
        end

        def initialize(df_module)
          @df_module = df_module
        end

        def validate!
          df_module.each_function { |fn| validate_function(fn) }
        end

        private

        attr_reader :df_module

        def validate_function(function)
          function.blocks.each do |block|
            defs = {}
            block.instructions.each do |instr|
              defs[instr.result] = instr if instr.result
              validate_instruction(instr, defs)
            end
          end
        end

        def validate_instruction(instr, defs)
          raise ArgumentError, "DFIR does not support opcode #{instr.opcode}" unless ALLOWED_OPS.include?(instr.opcode)

          case instr.opcode
          when :load_field
            source = defs[instr.inputs.first]
            if source && Array(source.axes) != Array(instr.axes)
              raise ArgumentError, "DFIR load_field must preserve axes"
            end
          when :select
            raise ArgumentError, "DFIR select expects 3 inputs" unless instr.inputs.size == 3
          when :make_object
            keys = Array(instr.attributes[:keys])
            raise ArgumentError, "DFIR make_object inputs/keys mismatch" unless keys.size == instr.inputs.size
          when :axis_broadcast
            expected = Array(instr.attributes[:to_axes]).map(&:to_sym)
            raise ArgumentError, "DFIR axis_broadcast axes mismatch" unless Array(instr.axes) == expected
          when :reduce
            over_axes = Array(instr.attributes[:over_axes]).map(&:to_sym)
            raise ArgumentError, "DFIR reduce missing over_axes" if over_axes.empty?
          end
        end
      end
    end
  end
end
