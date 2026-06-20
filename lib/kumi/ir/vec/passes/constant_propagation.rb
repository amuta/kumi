# frozen_string_literal: true

module Kumi
  module IR
    module Vec
      module Passes
        class ConstantPropagation < Kumi::IR::Passes::Base
          require_relative "support/instruction_cloner"
          require_relative "support/algebraic_identities"
          require_relative "../../passes/register_generator"

          def run(graph:, context: {})
            new_functions = graph.functions.values.map { rewrite_function(_1) }
            Kumi::IR::Vec::Module.new(name: graph.name, functions: new_functions)
          end

          private

          def rewrite_function(function)
            reg_gen = Kumi::IR::Passes::RegisterGenerator.new(function)
            new_blocks = function.blocks.map { rewrite_block(_1, reg_gen) }
            Kumi::IR::Base::Function.new(
              name: function.name,
              parameters: function.parameters,
              blocks: new_blocks
            )
          end

          def rewrite_block(block, reg_gen)
            constants = {}
            replacements = {}
            defs = {} # reg => defining instruction (post-rewrite), for dtype checks
            new_instrs = []

            # The Vec function's result is the LAST result-bearing instruction
            # (DCE and Loop lowering both read it that way), so dropping the
            # terminal would change which value the function returns. Identity
            # simplification therefore skips the terminal; the surviving
            # multiply/add there is cheap and gets cleaned at the Loop layer.
            terminal = block.terminal_instruction
            state = { constants: constants, replacements: replacements, defs: defs,
                      new_instrs: new_instrs, reg_gen: reg_gen, terminal: terminal }

            block.instructions.each { |instr| process_instruction(instr, state) }

            Kumi::IR::Base::Block.new(name: block.name, instructions: new_instrs)
          end

          def process_instruction(instr, state)
            constants = state[:constants]
            inputs = instr.uses.map { |reg| state[:replacements].fetch(reg, reg) }
            result = instr.defs.first

            case instr.opcode
            when :constant
              constants[result] = instr.attributes[:value] if result
              emit(state, instr)
            when :axis_broadcast
              # A broadcast scalar is still that scalar value for an algebraic
              # identity (x * broadcast(1.0) is x * 1.0).
              constants[result] = constants[inputs.first] if result && constants.key?(inputs.first)
              emit(state, rebuild(instr, inputs))
            when :map
              process_map(instr, inputs, result, state)
            else
              constants.delete(result) if result
              emit(state, rebuild(instr, inputs))
            end
          end

          def process_map(instr, inputs, result, state)
            constants = state[:constants]
            folded = fold_map(instr, inputs, constants, state[:reg_gen])
            if folded
              constants[result] = folded.attributes[:value] if result
              return emit(state, folded)
            end

            survivor = Support::AlgebraicIdentities.survivor(instr, inputs, constants, state[:defs]) unless instr.equal?(state[:terminal])
            if survivor
              # x * 1, x / 1, x - 0, integer x + 0 / x * 0 reduce to one operand;
              # rewrite the result to it and drop the map. The replacement flows
              # into later inputs via the lookup at the top of the loop.
              state[:replacements][result] = survivor if result
              constants[result] = constants[survivor] if result && constants.key?(survivor)
            else
              constants.delete(result) if result
              emit(state, rebuild(instr, inputs))
            end
          end

          def emit(state, instr)
            record(state[:defs], instr)
            state[:new_instrs] << instr
          end

          def record(defs, instr)
            defs[instr.result] = instr if instr.result
          end

          def rebuild(instr, inputs)
            return instr if instr.uses.empty? || inputs == instr.uses

            Support::InstructionCloner.clone(instr, inputs)
          end

          def fold_map(instr, inputs, constants, _reg_gen)
            axes = Array(instr.axes)
            return nil unless axes.empty?

            fn = instr.attributes[:fn]
            values = inputs.map { |reg| constants[reg] }
            return nil if values.any?(&:nil?)

            case fn
            when :"core.add"
              value = values[0] + values[1]
            when :"core.sub"
              value = values[0] - values[1]
            when :"core.mul:numeric"
              value = values[0] * values[1]
            else
              return nil
            end

            Ops::Constant.new(
              result: instr.result,
              value: value,
              axes: [],
              dtype: instr.dtype,
              metadata: instr.metadata
            )
          end
        end
      end
    end
  end
end
