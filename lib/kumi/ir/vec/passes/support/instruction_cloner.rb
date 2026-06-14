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
                Ops::AxisBroadcast.new(result:, value: inputs.first, from_axes: attrs[:from_axes], to_axes: attrs[:to_axes], dtype:,
                                       metadata:)
              when :axis_shift
                Ops::AxisShift.new(result:, source: inputs.first, axis: attrs[:axis], offset: attrs[:offset], policy: attrs[:policy],
                                   axes:, dtype:, metadata:)
              when :axis_cross
                Ops::AxisCross.new(result:, source: inputs.first, axis: attrs[:axis], source_axis: attrs[:source_axis],
                                   axes:, dtype:, metadata:)
              when :axis_outer
                Ops::AxisOuter.new(result:, source: inputs.first, axis: attrs[:axis], source_axis: attrs[:source_axis],
                                   axes:, dtype:, metadata:)
              when :axis_index
                Ops::AxisIndex.new(result:, axis: attrs[:axis], axes:, dtype:, metadata:)
              when :reduce
                Ops::Reduce.new(result:, fn: attrs[:fn], arg: inputs.first, over_axes: attrs[:over_axes], axes:, dtype:, metadata:)
              when :make_object
                Ops::MakeObject.new(result:, inputs: inputs, keys: attrs[:keys], axes:, dtype:, metadata:)
              else
                # No clone branch would silently keep the original inputs/result,
                # corrupting references when a Vec pass remaps registers. Every
                # Vec opcode must have a clone branch — fail loudly if one is missing.
                raise ArgumentError,
                      "InstructionCloner has no clone branch for Vec opcode #{instr.opcode.inspect}. " \
                      "Add one here (it must thread `inputs`/`result`/`attrs`), otherwise register " \
                      "remapping in Vec passes will silently corrupt references to this instruction."
              end
            end
          end
        end
      end
    end
  end
end
