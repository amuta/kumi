# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      # Enforces the LoopIR execution contract: only execution-shaped ops,
      # balanced loops, and registers defined before use. No vector-semantics
      # ops (map/broadcast/shift/reduce) may survive lowering.
      class Validator
        ALLOWED_OPS = %i[
          constant
          load_input
          load_field
          kernel_call
          select
          make_object
          ref
          loop_start
          loop_end
          array_init
          array_push
          array_len
          index_read
          shift_read
          shift_in_bounds
          acc_init
          acc_step
          acc_load
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
          raise ArgumentError, "LoopIR function #{function.name} missing return_reg" unless function.return_reg

          defs = {}
          depth = 0

          function.blocks.each do |block|
            block.instructions.each do |instr|
              validate_instruction(function, instr, defs)

              case instr.opcode
              when :loop_start
                depth += 1
                defs[instr.attributes[:index]] = instr
              when :loop_end
                depth -= 1
                raise ArgumentError, "LoopIR function #{function.name} has unbalanced loop_end" if depth.negative?
              end

              defs[instr.result] = instr if instr.result
            end
          end

          raise ArgumentError, "LoopIR function #{function.name} has unclosed loops" unless depth.zero?
          return if defs.key?(function.return_reg)

          raise ArgumentError, "LoopIR function #{function.name} returns undefined #{function.return_reg.inspect}"
        end

        def validate_instruction(function, instr, defs)
          raise ArgumentError, "LoopIR does not support opcode #{instr.opcode}" unless ALLOWED_OPS.include?(instr.opcode)

          instr.uses.each do |use|
            next if defs.key?(use)

            raise ArgumentError,
                  "LoopIR function #{function.name}: #{instr.opcode} uses undefined register #{use.inspect}"
          end

          case instr.opcode
          when :select
            raise ArgumentError, "LoopIR select expects 3 inputs" unless instr.inputs.size == 3
          when :make_object
            keys = Array(instr.attributes[:keys])
            raise ArgumentError, "LoopIR make_object inputs/keys mismatch" unless keys.size == instr.inputs.size
          when :shift_read
            policy = instr.attributes[:policy]
            raise ArgumentError, "LoopIR shift_read has invalid policy #{policy.inspect}" unless Ops::ShiftRead::POLICIES.include?(policy)
          end
        end
      end
    end
  end
end
