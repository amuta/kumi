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
          axis_cross
          axis_outer
          axis_index
          reduce
          make_object
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
          validate_no_dangling_uses(function)
        end

        # Every register a function uses must be defined in that same function.
        # A register-rewriting pass (gvn, peephole) can drop a defining
        # instruction while a consumer still points at it; left unchecked the
        # dangling use surfaces far downstream as an opaque LoopIR "cannot read
        # :vNN (nil)". Catch it here, at the producing boundary, naming the
        # offender.
        def validate_no_dangling_uses(function)
          instructions = function.blocks.flat_map(&:instructions)
          defs = instructions.each_with_object({}) { |instr, h| h[instr.result] = true if instr.result }

          instructions.each do |instr|
            instr.uses.each do |reg|
              next if defs[reg]

              raise ArgumentError,
                    "VecIR #{function.name}: #{instr.result.inspect}=#{instr.opcode} uses #{reg.inspect}, " \
                    "which no instruction defines (dangling register)"
            end
          end
        end

        def validate_instruction(instr)
          raise ArgumentError, "VecIR does not support opcode #{instr.opcode}" unless ALLOWED_OPS.include?(instr.opcode)

          dtype = instr.metadata[:dtype] || instr.dtype
          raise ArgumentError, "VecIR disallows tuple dtype (#{dtype})" if dtype.respond_to?(:element_types) && instr.opcode != :make_object

          case instr.opcode
          when :axis_broadcast
            expected = Array(instr.attributes[:to_axes]).map(&:to_sym)
            raise ArgumentError, "AxisBroadcast axes mismatch" unless Array(instr.axes) == expected
          when :make_object
            keys = Array(instr.attributes[:keys])
            raise ArgumentError, "VecIR make_object inputs/keys mismatch" unless keys.size == instr.inputs.size
          when :reduce
            over_axes = Array(instr.attributes[:over_axes]).map(&:to_sym)
            raise ArgumentError, "VecIR reduce missing over_axes" if over_axes.empty?
          end
        end
      end
    end
  end
end
