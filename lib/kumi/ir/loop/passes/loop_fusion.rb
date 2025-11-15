# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Passes
        class LoopFusion
          attr_reader :graph

          def run(graph:, context: {})
            @graph = graph
            graph.each_function do |fn|
              fuse_in_function(fn)
            end
            graph
          end

          private

          def fuse_in_function(function)
            block = function.entry_block
            instructions = block.instructions
            changed = true
            while changed
              instructions, changed = fuse_once(instructions)
            end
            block.instance_variable_set(:@instructions, instructions)
          end

          def fuse_once(instructions)
            new_instructions = []
            changed = false
            i = 0

            while i < instructions.length
              ins1 = instructions[i]

              if ins1.loop_control? && ins1.opcode == :loop_start
                end1_idx = find_matching_loop_end(instructions, i)
                pre_ops, post_ops, next_idx = classify_intervening_ops(instructions, end1_idx)

                if next_idx
                  ins2 = instructions[next_idx]
                  if ins2.opcode == :loop_start && ins1.inputs.first == ins2.inputs.first
                    changed = true

                    body1 = instructions[(i + 1)...end1_idx]
                    end2_idx = find_matching_loop_end(instructions, next_idx)
                    body2 = instructions[(next_idx + 1)...end2_idx]

                    remap = {
                      ins2.attributes[:element] => ins1.attributes[:element],
                      ins2.attributes[:index] => ins1.attributes[:index]
                    }
                    remapped_body2 = remap_registers(body2, remap)
                    fused_body = fuse_once(body1 + remapped_body2).first

                    new_instructions.concat(pre_ops)
                    new_instructions << ins1
                    new_instructions.concat(fused_body)
                    new_instructions << instructions[end1_idx]
                    new_instructions.concat(post_ops)

                    i = end2_idx + 1
                    next
                  end
                end
              end

              new_instructions << ins1
              i += 1
            end

            [new_instructions, changed]
          end

          def classify_intervening_ops(instructions, start_idx)
            pre_ops = []
            post_ops = []
            (start_idx + 1...instructions.length).each do |idx|
              instr = instructions[idx]
              case instr.opcode
              when :loop_start
                return [pre_ops, post_ops, idx]
              when :declare_accumulator
                pre_ops << instr
              when :load_accumulator
                post_ops << instr
              else
                return [[], [], nil]
              end
            end
            [[], [], nil]
          end

          def find_matching_loop_end(instructions, start_idx)
            depth = 1
            (start_idx + 1...instructions.length).each do |idx|
              case instructions[idx].opcode
              when :loop_start
                depth += 1
              when :loop_end
                depth -= 1
                return idx if depth.zero?
              end
            end
            raise "Unbalanced loop_start at index #{start_idx}"
          end

          def remap_registers(ops, remap)
            ops.map do |ins|
              new_inputs = Array(ins.inputs).map { |reg| remap.fetch(reg, reg) }
              ins.class.new(
                result: ins.result,
                axes: ins.axes,
                dtype: ins.dtype,
                inputs: new_inputs,
                attributes: ins.attributes,
                metadata: ins.metadata
              )
            end
          end
        end
      end
    end
  end
end
