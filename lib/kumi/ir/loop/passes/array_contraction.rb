# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Passes
        # Replaces single-pass intermediate arrays with the scalar that fills
        # them. After fusion, a vector materialized in one loop and read back
        # at the same index in the same loop is just a named wire:
        #
        #   array_init %a            =>   (removed)
        #   loop_start ...                loop_start ...
        #     %v = ...                      %v = ...
        #     array_push(%a, %v)            (removed)
        #     %r = index_read(%a, %i)       (uses of %r become uses of %v)
        #
        # An array contracts only when it has exactly one push, directly in a
        # loop body, and every other use is an index_read at that loop's index
        # inside the same loop. Anything else — shifts, lengths, escaping into
        # other arrays, the function return — keeps the materialization.
        class ArrayContraction < Kumi::IR::Passes::Base
          Occurrence = Struct.new(:instr, :nests, :parent_body, keyword_init: true)

          def run(graph:, context: {}) # rubocop:disable Lint/UnusedMethodArgument
            functions = graph.functions.values.map { |fn| process_function(fn) }
            Loop::Module.new(name: graph.name, functions: functions)
          end

          private

          def process_function(fn)
            items = Support.parse(fn.entry_block.instructions)
            occurrences = collect_occurrences(items)

            value_map = {}
            removed = {}.compare_by_identity
            contractible_arrays(fn, occurrences).each_value do |info|
              removed[info[:init]] = true
              removed[info[:push]] = true
              info[:reads].each do |read|
                removed[read] = true
                value_map[read.result] = info[:value]
              end
            end
            return fn if removed.empty?

            resolved = value_map.transform_values { |v| resolve(value_map, v) }
            instructions = Support.flatten(items)
                                  .reject { |instr| removed[instr] }
                                  .map { |instr| Support.remap(instr, resolved) }

            block = Base::Block.new(name: fn.entry_block.name, instructions: instructions)
            Loop::Function.new(name: fn.name, parameters: fn.parameters, blocks: [block], return_reg: fn.return_reg)
          end

          def collect_occurrences(items, nests = [], acc = [])
            items.each do |item|
              if item.is_a?(Support::Nest)
                acc << Occurrence.new(instr: item.start, nests: nests, parent_body: items)
                collect_occurrences(item.body, nests + [item], acc)
                acc << Occurrence.new(instr: item.end_node, nests: nests, parent_body: items)
              else
                acc << Occurrence.new(instr: item, nests: nests, parent_body: items)
              end
            end
            acc
          end

          def contractible_arrays(fn, occurrences)
            inits = {}
            by_array = Hash.new { |h, k| h[k] = [] }

            occurrences.each do |occ|
              instr = occ.instr
              inits[instr.result] = occ if instr.opcode == :array_init
              instr.uses.each { |r| by_array[r] << occ if inits.key?(r) }
            end

            inits.each_with_object({}) do |(reg, _init_occ), found|
              next if reg == fn.return_reg

              plan = contraction_plan(reg, inits[reg], by_array[reg])
              found[reg] = plan if plan
            end
          end

          def contraction_plan(reg, init_occ, uses)
            pushes, others = uses.partition { |o| o.instr.opcode == :array_push && o.instr.inputs[0] == reg }
            return nil unless pushes.size == 1

            push = pushes.first
            host = push.nests.last
            return nil unless host
            return nil unless push.parent_body.equal?(host.body)

            reads = []
            others.each do |occ|
              instr = occ.instr
              return nil unless instr.opcode == :index_read &&
                                instr.inputs[0] == reg &&
                                instr.inputs[1] == host.index_reg &&
                                occ.nests.include?(host)

              reads << instr
            end

            { init: init_occ.instr, push: push.instr, value: push.instr.inputs[1], reads: reads }
          end

          def resolve(map, reg)
            seen = {}
            while map.key?(reg)
              raise "contraction cycle at #{reg}" if seen[reg]

              seen[reg] = true
              reg = map[reg]
            end
            reg
          end
        end
      end
    end
  end
end
