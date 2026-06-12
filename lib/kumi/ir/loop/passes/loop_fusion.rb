# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Passes
        # Merges sibling loops over the same axis and source into one pass.
        #
        # The lowerer emits one loop per statement group, so loop-invariant
        # scalar work between two vector statements splits what could be a
        # single traversal. Fusion hoists the independent scalar barrier above
        # the first loop and appends the second loop's body, renaming its
        # element/index registers.
        #
        # A pair fuses only when it is provably safe:
        # - both loops iterate the same source register on the same axis
        # - every instruction between them depends on nothing the first loop
        #   defines, no array it pushes to, and no accumulator it steps
        # - the second loop touches arrays the first loop pushes to only via
        #   index_read at its own loop index (the value produced in the same
        #   fused iteration); shifts, lengths, or re-iteration of a partially
        #   built array block fusion (stencils legitimately need two passes)
        class LoopFusion < Kumi::IR::Passes::Base
          def run(graph:, context: {}) # rubocop:disable Lint/UnusedMethodArgument
            functions = graph.functions.values.map { |fn| process_function(fn) }
            Loop::Module.new(name: graph.name, functions: functions)
          end

          private

          def process_function(fn)
            items = Support.parse(fn.entry_block.instructions)
            items = fuse_level(items)
            block = Base::Block.new(name: fn.entry_block.name, instructions: Support.flatten(items))
            Loop::Function.new(name: fn.name, parameters: fn.parameters, blocks: [block], return_reg: fn.return_reg)
          end

          def fuse_level(items)
            items = items.map { |item| item.is_a?(Support::Nest) ? item.with_body(fuse_level(item.body)) : item }

            loop do
              candidate = find_fusable_pair(items)
              break unless candidate

              first, second = candidate
              left = items[first]
              right = items[second]
              barrier = items[(first + 1)...second]

              rename = { right.elem_reg => left.elem_reg, right.index_reg => left.index_reg }
              fused = left.with_body(fuse_level(left.body + Support.remap_items(right.body, rename)))
              items = items[0...first] + barrier + [fused] + items[(second + 1)..]
            end

            items
          end

          def find_fusable_pair(items)
            items.each_with_index do |left, first|
              next unless left.is_a?(Support::Nest)

              facts = loop_facts(left)
              ((first + 1)...items.size).each do |second|
                item = items[second]
                if item.is_a?(Support::Nest)
                  return [first, second] if compatible?(left, item) && body_safe?(item, facts)

                  break
                end
                break unless hoistable?(item, facts)
              end
            end
            nil
          end

          def compatible?(left, right)
            left.axis == right.axis && left.source_reg == right.source_reg
          end

          # defs: every register the loop produces; pushed: arrays it appends
          # to; accs: accumulators it steps. All three are dependencies later
          # code may only consume once the loop has fully run.
          def loop_facts(nest)
            facts = { defs: {}, pushed: {}, accs: {}, uses: {} }
            Support.each_instruction([nest]) do |instr|
              facts[:defs][instr.result] = true if instr.result
              facts[:pushed][instr.inputs[0]] = true if instr.opcode == :array_push
              facts[:accs][instr.inputs[0]] = true if instr.opcode == :acc_step
              instr.uses.each { |r| facts[:uses][r] = true }
            end
            facts
          end

          def hoistable?(instr, facts)
            return false if instr.uses.any? { |r| facts[:defs][r] || facts[:pushed][r] || facts[:accs][r] }
            return false if instr.opcode == :array_push && facts[:uses][instr.inputs[0]]
            return false if instr.opcode == :acc_step && facts[:uses][instr.inputs[0]]

            true
          end

          def body_safe?(nest, facts)
            return false if facts[:pushed][nest.source_reg]

            safe = true
            Support.each_instruction([nest]) do |instr|
              next unless safe

              safe = false if instr.uses.any? { |r| facts[:accs][r] }
              touched = instr.uses.select { |r| facts[:pushed][r] }
              next if touched.empty?

              next if instr.opcode == :index_read &&
                      touched == [instr.inputs[0]] &&
                      instr.inputs[1] == nest.index_reg

              safe = false
            end
            safe
          end
        end
      end
    end
  end
end
