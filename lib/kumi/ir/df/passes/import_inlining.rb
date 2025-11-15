# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Passes
        class ImportInlining < Kumi::IR::Passes::Base
          def initialize(loader: nil)
            @loader = loader
          end

          def run(graph:, context: {})
            loader = @loader || build_loader(context)
            return graph unless loader

            functions = graph.functions.values.map { |fn| rewrite_function(fn, loader) }
            Kumi::IR::DF::Graph.new(name: graph.name, functions: functions)
          end

          private

          attr_reader :loader

          def build_loader(context)
            imported = context[:imported_schemas]
            return nil unless imported && !imported.empty?

            Kumi::IR::DF::ImportLoader.new(imported)
          end

          def rewrite_function(fn, loader)
            reg_gen = RegGenerator.new(fn)
            new_blocks = fn.blocks.map { |block| rewrite_block(block, loader, reg_gen) }
            Kumi::IR::DF::Function.new(
              name: fn.name,
              parameters: fn.parameters,
              blocks: new_blocks,
              return_stamp: fn.return_stamp
            )
          end

          def rewrite_block(block, loader, reg_gen)
            replacements = {}
            new_instructions = []

            block.each do |instr|
              new_inputs = instr.inputs.map { |reg| replacements.fetch(reg, reg) }

              if instr.opcode == :import_call
                inlined, result_reg = inline_import(instr, new_inputs, loader, reg_gen)
                if inlined
                  new_instructions.concat(inlined)
                  replacements[instr.result] = result_reg
                  next
                end
              end

              cloned = Support::InstructionCloner.clone(instr, new_inputs)
              new_instructions << cloned
            end

            Kumi::IR::Base::Block.new(name: block.name, instructions: new_instructions)
          end

          def inline_import(instr, resolved_inputs, loader, reg_gen)
            attrs = instr.attributes || {}
            fn_name = attrs[:fn_name]&.to_sym
            return nil unless fn_name

            callee = loader.function(fn_name)
            return nil unless callee
            return nil if references_declarations?(callee)

            mapping_keys = Array(attrs[:mapping_keys]).map(&:to_sym)
            return nil unless mapping_keys.length == resolved_inputs.length

            call_axes = Array(instr.axes).map(&:to_sym)
            arg_map = mapping_keys.zip(resolved_inputs).to_h

            axes_map = build_axis_map(function_output_axes(callee), call_axes)
            extra_axes = call_axes.reject { |ax| axes_map.value?(ax) }

            inliner = Kumi::IR::DF::ImportInliner.new(axis_map: axes_map, extra_axes: extra_axes)
            remapped_fn = inliner.remap_function(callee)

            block = remapped_fn.entry_block
            return nil unless block

            value_map = {}
            emitted = []

            block.instructions.each do |callee_instr|
              if callee_instr.opcode == :load_input
                key = callee_instr.attributes[:key]&.to_sym
                arg_reg = arg_map[key]
                return nil unless arg_reg

                value_map[callee_instr.result] = arg_reg
                next
              end

              new_inputs = callee_instr.inputs.map do |reg|
                value_map.fetch(reg) { return nil }
              end

              new_result = callee_instr.result ? reg_gen.next : nil
              cloned = Support::InstructionCloner.clone(
                callee_instr,
                new_inputs,
                metadata: callee_instr.metadata,
                attributes: callee_instr.attributes,
                result: new_result
              )
              emitted << cloned
              value_map[callee_instr.result] = new_result if callee_instr.result
            end

            final_reg = value_map[block.instructions.reverse.find(&:result)&.result]
            return nil unless final_reg

            [emitted, final_reg]
          end

          def build_axis_map(callee_axes, target_axes)
            axis_pairs = callee_axes.zip(target_axes)
            axis_pairs.each_with_object({}) do |(from, to), memo|
              break memo unless from && to
              memo[from] = to
            end
          end

          def function_output_axes(function)
            function.blocks.flat_map(&:instructions).reverse_each do |instr|
              next unless instr.result

              return Array(instr.axes).map(&:to_sym)
            end
            []
          end

          def references_declarations?(function)
            function.blocks.any? do |block|
              block.any? { |instr| instr.opcode == :decl_ref }
            end
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
