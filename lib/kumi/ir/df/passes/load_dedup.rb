# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Passes
        class LoadDedup < Kumi::IR::Passes::Base
          def run(graph:, context: {})
            functions = graph.functions.values.map { |fn| rewrite_function(fn) }
            Kumi::IR::DF::Graph.new(name: graph.name, functions: functions)
          end

          private

          def rewrite_function(fn)
            new_blocks = fn.blocks.map { |block| rewrite_block(block) }
            Kumi::IR::DF::Function.new(
              name: fn.name,
              parameters: fn.parameters,
              blocks: new_blocks,
              return_stamp: fn.return_stamp
            )
          end

          def rewrite_block(block)
            replacements = {}
            load_inputs = {}
            load_fields = {}
            new_instructions = []

            block.each do |instr|
              new_inputs = instr.inputs.map { |reg| replacements.fetch(reg, reg) }

              case instr.opcode
              when :load_input
                key = load_input_key(instr)
                if key && load_inputs[key]
                  replacements[instr.result] = load_inputs[key]
                  next
                end
                cloned = Support::InstructionCloner.clone(instr, new_inputs)
                new_instructions << cloned
                load_inputs[key] = cloned.result if key && cloned.result
              when :load_field
                key = load_field_key(instr, new_inputs)
                cache = field_cache_for(instr, load_fields)
                if key && cache[key]
                  replacements[instr.result] = cache[key]
                  next
                end
                cloned = Support::InstructionCloner.clone(instr, new_inputs)
                new_instructions << cloned
                cache[key] = cloned.result if key && cloned.result
              else
                cloned = Support::InstructionCloner.clone(instr, new_inputs)
                new_instructions << cloned
              end
            end

            Kumi::IR::Base::Block.new(name: block.name, instructions: new_instructions)
          end

          def load_input_key(instr)
            attrs = instr.attributes || {}
            key = attrs[:plan_ref] || attrs[:key]
            [key]
          end

          def load_field_key(instr, inputs)
            attrs = instr.attributes || {}
            [inputs.first, attrs[:field], attrs[:plan_ref]]
          end

          def field_cache_for(instr, caches)
            key = instr.inputs.first
            caches[key] ||= {}
          end
        end
      end
    end
  end
end
