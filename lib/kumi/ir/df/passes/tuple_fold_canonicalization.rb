# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Passes
        class TupleFoldCanonicalization < Kumi::IR::Passes::Base
          def run(graph:, context: {})
            functions = graph.functions.values.map { rewrite_function(_1) }
            Kumi::IR::DF::Graph.new(name: graph.name, functions:)
          end

          private

          def rewrite_function(function)
            reg_gen = RegGenerator.new(function)
            new_blocks = function.blocks.map { rewrite_block(_1, reg_gen) }
            Kumi::IR::DF::Function.new(
              name: function.name,
              parameters: function.parameters,
              blocks: new_blocks,
              return_stamp: function.return_stamp
            )
          end

          def rewrite_block(block, reg_gen)
            usage = usage_counts(block)
            replacements = {}
            array_defs = {}
            value_info = {}
            new_instructions = []

            block.each do |instr|
              new_inputs = instr.inputs.map { |reg| replacements.fetch(reg, reg) }

              case instr.opcode
              when :array_build
                cloned = Support::InstructionCloner.clone(instr, new_inputs)
                new_instructions << cloned
                value_info[cloned.result] = { dtype: cloned.dtype, axes: cloned.axes } if cloned.result
                array_defs[cloned.result] = {
                  elements: new_inputs.dup,
                  axes: cloned.axes,
                  element_dtype: element_dtype_for(new_inputs, value_info, cloned.dtype),
                  emitted_index: new_instructions.length - 1,
                  exclusive: usage.fetch(cloned.result, 0) == 1
                }
              when :fold
                if rewritten = rewrite_fold(instr, new_inputs, array_defs, value_info, new_instructions, reg_gen)
                  replacements[instr.result] = rewritten
                  next
                end

                cloned = Support::InstructionCloner.clone(instr, new_inputs)
                new_instructions << cloned
                value_info[cloned.result] = { dtype: cloned.dtype, axes: cloned.axes } if cloned.result
              else
                cloned = Support::InstructionCloner.clone(instr, new_inputs)
                new_instructions << cloned
                value_info[cloned.result] = { dtype: cloned.dtype, axes: cloned.axes } if cloned.result
              end
            end

            filtered = new_instructions.compact
            Kumi::IR::Base::Block.new(name: block.name, instructions: filtered)
          end

          def rewrite_fold(instr, inputs, array_defs, value_info, new_instructions, reg_gen)
            fn = instr.attributes[:fn]&.to_sym
            return nil unless fn == :"agg.sum"
            source = inputs.first
            array_info = array_defs[source]
            return nil unless array_info && array_info[:exclusive]

            elements = array_info[:elements]
            return nil if elements.empty?

            axes = array_info[:axes] || instr.axes
            element_dtype = array_info[:element_dtype] || scalar_from_tuple(instr.dtype)
            return nil unless element_dtype

            new_instructions[array_info[:emitted_index]] = nil
            acc = elements.first

            elements.drop(1).each do |elem|
              temp = reg_gen.next
              new_instr = Kumi::IR::DF::Ops::Map.new(
                result: temp,
                fn: :"core.add",
                args: [acc, elem],
                axes: axes,
                dtype: element_dtype,
                metadata: { dtype: element_dtype, axes: axes }
              )
              new_instructions << new_instr
              value_info[temp] = { dtype: element_dtype, axes: axes }
              acc = temp
            end

            array_defs.delete(source)
            value_info.delete(source)
            acc
          end

          def element_dtype_for(elements, value_info, fallback)
            elements.each do |reg|
              info = value_info[reg]
              return info[:dtype] if info && info[:dtype]
            end
            scalar_from_tuple(fallback)
          end

          def scalar_from_tuple(dtype)
            return nil unless dtype.respond_to?(:element_types)
            dtype.element_types.first
          end

          def usage_counts(block)
            counts = Hash.new(0)
            block.each do |instr|
              instr.inputs.each do |input|
                counts[input] += 1 if input.is_a?(Symbol)
              end
            end
            counts
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
