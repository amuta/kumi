# frozen_string_literal: true

module Kumi
  module IR
    module Vec
      module Passes
        class ConstantPropagation < Kumi::IR::Passes::Base
          def run(graph:, context: {})
            new_functions = graph.functions.values.map { rewrite_function(_1) }
            Kumi::IR::Vec::Module.new(name: graph.name, functions: new_functions)
          end

          private

          def rewrite_function(function)
            reg_gen = RegGenerator.new(function)
            new_blocks = function.blocks.map { rewrite_block(_1, reg_gen) }
            Kumi::IR::Base::Function.new(
              name: function.name,
              parameters: function.parameters,
              blocks: new_blocks,
              return_stamp: function.return_stamp
            )
          end

          def rewrite_block(block, reg_gen)
            constants = {}
            replacements = {}
            new_instrs = []

            block.instructions.each do |instr|
              inputs = instr.inputs.map { |reg| replacements.fetch(reg, reg) }

              case instr.opcode
              when :constant
                constants[instr.result] = instr.attributes[:value]
                new_instrs << instr
              when :map
                folded = fold_map(instr, inputs, constants, reg_gen)
                if folded
                  constants[instr.result] = folded.attributes[:value]
                  new_instrs << folded
                else
                  constants.delete(instr.result)
                  new_instrs << instr
                end
              else
                constants.delete(instr.result)
                new_instrs << instr
              end
            end

            Kumi::IR::Base::Block.new(name: block.name, instructions: new_instrs)
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

          class RegGenerator
            def initialize(function)
              @counter = extract_highest(function)
            end

            def next
              @counter += 1
              :"v#{@counter}"
            end

            private

            def extract_highest(function)
              regs = function.blocks.flat_map(&:instructions).map(&:result).compact
              nums = regs.filter_map do |reg|
                match = reg.to_s.match(/^v(\d+)$/)
                match && match[1].to_i
              end
              nums.max || 0
            end
          end
        end
      end
    end
  end
end
