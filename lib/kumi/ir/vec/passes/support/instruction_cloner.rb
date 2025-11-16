# frozen_string_literal: true

module Kumi
  module IR
    module Vec
      module Passes
        module Support
          module InstructionCloner
            module_function

            def clone(instr, inputs, attributes: nil, metadata: nil, result: nil, axes: nil, dtype: nil)
              metadata ||= instr.metadata || { dtype: instr.dtype, axes: instr.axes }
              attrs = attributes || instr.attributes || {}
              result ||= instr.result
              axes ||= metadata[:axes] || instr.axes
              dtype ||= metadata[:dtype] || instr.dtype

              case instr.opcode
              when :constant
                Ops::Constant.new(result:, value: attrs[:value], axes:, dtype:, metadata:)
              when :load_input
                Ops::LoadInput.new(result:, key: attrs[:key], chain: attrs[:chain] || [], axes:, dtype:, metadata:)
              when :load_field
                Ops::LoadField.new(result:, object: inputs.first, field: attrs[:field], axes:, dtype:, metadata:)
              when :map
                Ops::Map.new(result:, fn: attrs[:fn], args: inputs, axes:, dtype:, metadata:)
              when :select
                Ops::Select.new(result:, cond: inputs[0], on_true: inputs[1], on_false: inputs[2], axes:, dtype:, metadata:)
              when :axis_broadcast
                Ops::AxisBroadcast.new(result:, value: inputs.first, from_axes: attrs[:from_axes], to_axes: attrs[:to_axes], dtype:, metadata:)
              when :axis_shift
                Ops::AxisShift.new(result:, source: inputs.first, axis: attrs[:axis], offset: attrs[:offset], policy: attrs[:policy], axes:, dtype:, metadata:)
              when :axis_index
                Ops::AxisIndex.new(result:, axis: attrs[:axis], axes:, dtype:, metadata:)
              when :reduce
                Ops::Reduce.new(result:, fn: attrs[:fn], arg: inputs.first, over_axes: attrs[:over_axes], axes:, dtype:, metadata:)
              else
                instr
              end
            end
          end
        end
      end
    end
  end
end
