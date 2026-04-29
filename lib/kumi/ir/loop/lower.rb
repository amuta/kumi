# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      class Lower
        def initialize(vec_module:, context: {})
          @vec_module = vec_module
          @context = context
        end

        def call
          loop_module = Loop::Module.new(name: @vec_module.name)
          @vec_module.each_function do |vec_function|
            loop_module.add_function(lower_function(vec_function))
          end
          loop_module
        end

        private

        def lower_function(vec_function)
          instructions = []
          reg_map = {}

          vec_function.blocks.each do |block|
            block.instructions.each do |instr|
              lowered = lower_instruction(instr, reg_map)
              Array(lowered).each { |li| instructions << li } if lowered
            end
          end

          return_reg = resolve_reg(last_result_reg(vec_function), reg_map)
          loop_block = Base::Block.new(name: :entry, instructions: instructions)
          Loop::Function.new(
            name: vec_function.name,
            blocks: [loop_block],
            return_reg: return_reg
          )
        end

        def lower_instruction(instr, reg_map)
          inputs = instr.uses.map { |r| resolve_reg(r, reg_map) }
          dtype = instr.dtype
          axes = instr.axes
          attrs = instr.attributes || {}

          case instr.opcode
          when :constant
            reg_map[instr.result] = instr.result
            Ops::Constant.new(result: instr.result, value: attrs[:value], axes: axes, dtype: dtype, metadata: instr.metadata)
          when :load_input
            reg_map[instr.result] = instr.result
            Ops::LoadInput.new(result: instr.result, key: attrs[:key], chain: attrs[:chain] || [], axes: axes, dtype: dtype, metadata: instr.metadata)
          when :load_field
            reg_map[instr.result] = instr.result
            Ops::LoadField.new(result: instr.result, object: inputs.first, field: attrs[:field], axes: axes, dtype: dtype, metadata: instr.metadata)
          when :map
            reg_map[instr.result] = instr.result
            Ops::KernelCall.new(result: instr.result, fn: attrs[:fn], args: inputs, axes: axes, dtype: dtype, metadata: instr.metadata)
          when :select
            reg_map[instr.result] = instr.result
            Ops::Select.new(result: instr.result, cond: inputs[0], on_true: inputs[1], on_false: inputs[2], axes: axes, dtype: dtype, metadata: instr.metadata)
          when :make_object
            reg_map[instr.result] = instr.result
            Ops::MakeObject.new(result: instr.result, inputs: inputs, keys: attrs[:keys], axes: axes, dtype: dtype, metadata: instr.metadata)
          when :axis_broadcast
            reg_map[instr.result] = inputs.first
            nil
          when :axis_shift
            raise NotImplementedError, "LoopIR lowering does not yet handle axis_shift"
          when :axis_index
            raise NotImplementedError, "LoopIR lowering does not yet handle axis_index"
          when :reduce
            reg_map[instr.result] = instr.result
            Ops::Reduce.new(
              result: instr.result,
              fn: attrs[:fn],
              arg: inputs.first,
              over_axes: attrs[:over_axes],
              axes: axes,
              dtype: dtype,
              metadata: instr.metadata
            )
          else
            raise NotImplementedError, "LoopIR lowering does not handle #{instr.opcode.inspect}"
          end
        end

        def last_result_reg(vec_function)
          last_block = vec_function.blocks.last
          last_instr = last_block&.instructions&.reverse&.find { |i| i.result }
          last_instr&.result
        end

        def resolve_reg(reg, reg_map)
          seen = []
          while reg_map.key?(reg) && !seen.include?(reg)
            seen << reg
            reg = reg_map[reg]
          end
          reg
        end
      end
    end
  end
end
