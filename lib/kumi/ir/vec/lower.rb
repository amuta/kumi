# frozen_string_literal: true

module Kumi
  module IR
    module Vec
      class Lower
        attr_reader :df_module

        class RegGenerator
          def initialize
            @counter = 0
          end

          def next
            @counter += 1
            :"vec_tmp#{@counter}"
          end
        end

        def initialize(df_module:)
          @df_module = df_module
          @reg_generator = RegGenerator.new
        end

        def call
          vec_module = Vec::Module.new(name: df_module.name)
          df_module.each_function do |df_function|
            vec_function = lower_function(df_function)
            vec_module.add_function(vec_function)
          end
          vec_module
        end

        private

        def lower_function(df_function)
          blocks = df_function.blocks.map { |block| lower_block(block) }
          Vec::Function.new(
            name: df_function.name,
            parameters: df_function.parameters,
            blocks: blocks,
            return_stamp: df_function.return_stamp
          )
        end

        def lower_block(block)
          value_info = build_value_info(block)
          new_instrs = []
          block.instructions.each do |instr|
            lowered = lower_instruction(instr, value_info)
            Array(lowered).each { |li| new_instrs << li }
          end
          Kumi::IR::Base::Block.new(name: block.name, instructions: new_instrs)
        end

        def build_value_info(block)
          info = {}
          block.instructions.each do |instr|
            next unless instr.result

            axes = instr.metadata[:axes] || instr.axes
            dtype = instr.metadata[:dtype] || instr.dtype
            info[instr.result] = { axes: Array(axes).map(&:to_sym), dtype: dtype }
          end
          info
        end

        def lower_instruction(instr, value_info)
          metadata = instr.metadata || {}
          dtype = metadata[:dtype] || instr.dtype
          axes = metadata[:axes] || instr.axes
          attrs = instr.attributes || {}

          case instr.opcode
          when :constant
            Ops::Constant.new(result: instr.result, value: attrs[:value], axes:, dtype:, metadata:)
          when :load_input
            Ops::LoadInput.new(result: instr.result, key: attrs[:key], chain: attrs[:chain] || [], axes:, dtype:, metadata:)
          when :load_field
            Ops::LoadField.new(result: instr.result, object: instr.inputs.first, field: attrs[:field], axes:, dtype:, metadata:)
          when :map
            Ops::Map.new(result: instr.result, fn: attrs[:fn], args: instr.inputs, axes:, dtype:, metadata:)
          when :select
            Ops::Select.new(result: instr.result, cond: instr.inputs[0], on_true: instr.inputs[1], on_false: instr.inputs[2], axes:, dtype:, metadata:)
          when :axis_broadcast
            Ops::AxisBroadcast.new(result: instr.result, value: instr.inputs.first, from_axes: attrs[:from_axes], to_axes: attrs[:to_axes] || axes, dtype:, metadata:)
          when :axis_shift
            Ops::AxisShift.new(result: instr.result, source: instr.inputs.first, axis: attrs[:axis], offset: attrs[:offset], policy: attrs[:policy], axes:, dtype:, metadata:)
          when :axis_index
            Ops::AxisIndex.new(result: instr.result, axis: attrs[:axis], axes:, dtype:, metadata:)
          when :reduce
            Ops::Reduce.new(result: instr.result, fn: attrs[:fn], arg: instr.inputs.first, over_axes: attrs[:over_axes], axes:, dtype:, metadata:)
          when :make_object
            lower_make_object(instr, axes, dtype, metadata, attrs, value_info)
          else
            raise NotImplementedError, "Vec lowering does not handle opcode #{instr.opcode.inspect}"
          end
        end

        def lower_make_object(instr, axes, dtype, metadata, attrs, value_info)
          target_axes = Array(axes).map(&:to_sym)
          emitted = []
          converted_inputs = instr.inputs.map do |input|
            info = value_info[input]
            input_axes = info ? Array(info[:axes]) : target_axes
            if input_axes == target_axes
              input
            elsif input_axes.empty? && !target_axes.empty?
              broadcast_reg = @reg_generator.next
              broadcast = Ops::AxisBroadcast.new(
                result: broadcast_reg,
                value: input,
                from_axes: [],
                to_axes: target_axes,
                dtype: info ? info[:dtype] : dtype,
                metadata: metadata.merge(axes: target_axes)
              )
              emitted << broadcast
              broadcast_reg
            else
              raise NotImplementedError, "Vec lowering cannot align axes #{input_axes.inspect} -> #{target_axes.inspect} for make_object"
            end
          end

          emitted << Ops::MakeObject.new(result: instr.result, inputs: converted_inputs, keys: attrs[:keys], axes: target_axes, dtype:, metadata:)
          emitted
        end
      end
    end
  end
end
