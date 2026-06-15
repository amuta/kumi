# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Passes
        module Support
          # Structured view of a LoopIR instruction stream: loop_start/loop_end
          # pairs become Nest items so passes can reason about loops as units,
          # then serialize back to the flat form.
          class Nest
            attr_reader :start, :body, :end_node

            def initialize(start:, body:, end_node:)
              @start = start
              @body = body
              @end_node = end_node
            end

            def axis = @start.attributes[:axis]
            def source_reg = @start.inputs.first
            def elem_reg = @start.result
            def index_reg = @start.attributes[:index]

            def with_body(body)
              Nest.new(start: @start, body: body, end_node: @end_node)
            end
          end

          module_function

          def parse(instructions)
            root = []
            bodies = [root]
            starts = []

            instructions.each do |instr|
              case instr.opcode
              when :loop_start
                starts << instr
                bodies << []
              when :loop_end
                body = bodies.pop
                bodies.last << Nest.new(start: starts.pop, body: body, end_node: instr)
              else
                bodies.last << instr
              end
            end

            root
          end

          def flatten(items)
            items.flat_map do |item|
              item.is_a?(Nest) ? [item.start, *flatten(item.body), item.end_node] : [item]
            end
          end

          def each_instruction(items, &blk)
            items.each do |item|
              if item.is_a?(Nest)
                yield(item.start)
                each_instruction(item.body, &blk)
                yield(item.end_node)
              else
                yield(item)
              end
            end
          end

          # Rebuilds an instruction with inputs substituted through the map.
          # Downstream consumers dispatch on opcode, so the generic node class
          # is sufficient for rewritten instructions.
          def remap(instr, map)
            return instr if instr.uses.none? { |r| map.key?(r) }

            Kumi::IR::Base::Instruction.new(
              opcode: instr.opcode,
              result: instr.result,
              inputs: instr.inputs.map { |r| map.fetch(r, r) },
              attributes: instr.attributes,
              metadata: instr.metadata,
              effects: instr.effects
            )
          end

          def remap_items(items, map)
            items.map do |item|
              if item.is_a?(Nest)
                Nest.new(start: remap(item.start, map), body: remap_items(item.body, map), end_node: item.end_node)
              else
                remap(item, map)
              end
            end
          end
        end
      end
    end
  end
end
