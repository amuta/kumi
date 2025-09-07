# lib/kumi/core/lir/analyze.rb
# Single-pass context builder. Derives loop tables and per-register lineage.
module Kumi
  module Core
    module LIR
      module Analyze
        module_function

        # Returns:
        # - loop_table:  { loop_id => { id:, axis:, input:, start:, end: } }
        # - active_axes: Array<Array<Symbol>> per instruction index
        # - active_ids:  Array<Array<Symbol>> per instruction index
        # - definition_table: { reg => index }
        # - use_table:   { reg => [indices...] }
        # - register_axes: { reg => [:axis...] } lineage at def site
        # - register_ids:  { reg => [:L1,:L2,...] } loop ids at def site
        def context(instructions, ids: nil)
          frames = []
          loop_table = {}
          active_axes = Array.new(instructions.length) { [] }
          active_ids  = Array.new(instructions.length) { [] }
          definition_table = {}
          use_table = Hash.new { |h, k| h[k] = [] }

          instructions.each_with_index do |instruction, idx|
            definition_table[instruction.result_register] = idx if instruction.result_register
            instruction.inputs&.each { |r| use_table[r] << idx }

            case instruction.opcode
            when :LoopStart
              id = (instruction.attributes[:id] ||= (ids || Ids.new).generate_loop_id)
              frames << { id:, axis: instruction.attributes[:axis], input: instruction.inputs&.first, start: idx }
            when :LoopEnd
              frame = frames.pop or raise Error, "LoopEnd without frame at #{idx}"
              loop_table[frame[:id]] = frame.merge(end: idx)
            end

            active_axes[idx] = frames.map { _1[:axis] }
            active_ids[idx]  = frames.map { _1[:id] }
          end

          raise Error, "unclosed loops" unless frames.empty?

          register_axes = {}
          register_ids  = {}
          definition_table.each do |reg, def_idx|
            register_axes[reg] = active_axes[def_idx]
            register_ids[reg]  = active_ids[def_idx]
          end

          {
            loop_table:,
            active_axes:,
            active_ids:,
            definition_table:,
            use_table:,
            register_axes:,
            register_ids:
          }
        end
      end
    end
  end
end