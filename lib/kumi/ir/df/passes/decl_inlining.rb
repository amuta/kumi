# frozen_string_literal: true

require "set"

module Kumi
  module IR
    module DF
      module Passes
        class DeclInlining < Kumi::IR::Passes::Base
          InlineResult = Struct.new(:instructions, :result)

          def run(graph:, context: {})
            functions = graph.functions.values.map { |fn| rewrite_function(fn, graph) }
            Kumi::IR::DF::Graph.new(name: graph.name, functions: functions)
          end

          private

          def rewrite_function(fn, graph)
            reg_gen = RegGenerator.new(fn)
            new_blocks = fn.blocks.map { |block| rewrite_block(block, graph, reg_gen) }
            Kumi::IR::DF::Function.new(
              name: fn.name,
              parameters: fn.parameters,
              blocks: new_blocks,
              return_stamp: fn.return_stamp
            )
          end

          def rewrite_block(block, graph, reg_gen)
            replacements = {}
            new_instructions = []

            block.each do |instr|
              new_inputs = instr.inputs.map { |reg| replacements.fetch(reg, reg) }

              if instr.opcode == :decl_ref
                ref_name = instr.attributes[:name]&.to_sym
                inlined = inline_declaration(graph, ref_name, reg_gen, Set.new)
                if inlined
                  new_instructions.concat(inlined.instructions)
                  replacements[instr.result] = inlined.result
                  next
                end
              end

              cloned = Support::InstructionCloner.clone(instr, new_inputs)
              new_instructions << cloned
              replacements[instr.result] = cloned.result if instr.result
            end

            Kumi::IR::Base::Block.new(name: block.name, instructions: new_instructions)
          end

          def inline_declaration(graph, name, reg_gen, stack)
            function = graph.functions[name]
            return nil unless function
            return nil if stack.include?(name)

            stack = stack.dup
            stack << name

            replacements = {}
            emitted = []

            function.blocks.each do |block|
              block.instructions.each do |instr|
                if instr.opcode == :decl_ref
                  nested_name = instr.attributes[:name]&.to_sym
                  nested = inline_declaration(graph, nested_name, reg_gen, stack)
                  return nil unless nested

                  emitted.concat(nested.instructions)
                  replacements[instr.result] = nested.result
                  next
                end

                new_inputs = instr.inputs.map { |reg| replacements.fetch(reg, reg) }
                new_result = instr.result ? reg_gen.next : nil
                cloned = Support::InstructionCloner.clone(
                  instr,
                  new_inputs,
                  metadata: instr.metadata,
                  attributes: instr.attributes,
                  result: new_result
                )
                emitted << cloned
                replacements[instr.result] = new_result if instr.result
              end
            end

            last_instr = function.blocks.flat_map(&:instructions).reverse.find(&:result)
            final_reg = last_instr && replacements[last_instr.result]
            return nil unless final_reg

            InlineResult.new(emitted, final_reg)
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
