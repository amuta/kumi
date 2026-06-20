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

          # `defs` holds only the registers that are LIVE at the current point:
          # each maps to the loop depth where it was defined, and a register
          # defined inside a loop is dropped when that loop closes. A bare
          # "defined somewhere" set would let a register defined inside a loop be
          # read after loop_end — which the validator must reject, because that
          # IR compiles to a block-local read (nil in Ruby, a crash in JS).
          defs = {}
          closed = {} # registers that WERE defined but fell out of scope at loop_end
          depth = 0

          function.blocks.each do |block|
            block.instructions.each do |instr|
              validate_instruction(function, instr, defs, closed)

              case instr.opcode
              when :loop_start
                depth += 1
                defs[instr.attributes[:index]] = depth
              when :loop_end
                drop_defs_at_depth(defs, closed, depth)
                depth -= 1
                raise ArgumentError, "LoopIR function #{function.name} has unbalanced loop_end" if depth.negative?
              end

              if instr.result
                defs[instr.result] = depth
                closed.delete(instr.result)
              end
            end
          end

          raise ArgumentError, "LoopIR function #{function.name} has unclosed loops" unless depth.zero?
          return if defs.key?(function.return_reg)

          raise ArgumentError, "LoopIR function #{function.name} returns undefined #{function.return_reg.inspect}"
        end

        # Drop every register defined at the loop level being closed; they fall
        # out of scope at loop_end. Remember them in `closed` so a later use can
        # be reported as an out-of-scope read rather than a generic undefined.
        def drop_defs_at_depth(defs, closed, depth)
          defs.each { |reg, d| closed[reg] = true if d == depth }
          defs.delete_if { |_, d| d == depth }
        end

        def validate_instruction(function, instr, defs, closed = {})
          raise ArgumentError, "LoopIR does not support opcode #{instr.opcode}" unless ALLOWED_OPS.include?(instr.opcode)

          instr.uses.each do |use|
            next if defs.key?(use)

            if closed.key?(use)
              raise ArgumentError,
                    "LoopIR function #{function.name}: #{instr.opcode} uses register #{use.inspect} out of scope — " \
                    "it is defined inside a loop that has already closed, so the read would be invalid (block-local)"
            end

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
