# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Passes
        module Support
          module InstructionCloner
            module_function

            def clone(instr, inputs, attributes: nil, metadata: nil, result: nil)
              metadata ||= instr.metadata || { dtype: instr.dtype, axes: instr.axes }
              attrs = attributes || instr.attributes || {}
              result ||= instr.result

              case instr.opcode
              when :load_input
                Ops::LoadInput.new(
                  result: result,
                  key: attrs[:key],
                  chain: attrs[:chain] || [],
                  plan_ref: attrs[:plan_ref],
                  axes: metadata[:axes] || instr.axes,
                  dtype: metadata[:dtype] || instr.dtype,
                  metadata: metadata
                )
              when :load_field
                Ops::LoadField.new(
                  result: result,
                  object: inputs.first,
                  field: attrs[:field],
                  plan_ref: attrs[:plan_ref],
                  axes: metadata[:axes] || instr.axes,
                  dtype: metadata[:dtype] || instr.dtype,
                  metadata: metadata
                )
              when :constant
                Ops::Constant.new(result: result, value: attrs[:value], axes: metadata[:axes] || instr.axes, dtype: metadata[:dtype] || instr.dtype, metadata: metadata)
              when :decl_ref
                Ops::DeclRef.new(result: result, name: attrs[:name], axes: metadata[:axes] || instr.axes, dtype: metadata[:dtype] || instr.dtype, metadata: metadata)
              when :map
                Ops::Map.new(result: result, fn: attrs[:fn], args: inputs, axes: metadata[:axes] || instr.axes, dtype: metadata[:dtype] || instr.dtype, metadata: metadata)
              when :select
                Ops::Select.new(
                  result: result,
                  cond: inputs[0],
                  on_true: inputs[1],
                  on_false: inputs[2],
                  axes: metadata[:axes] || instr.axes,
                  dtype: metadata[:dtype] || instr.dtype,
                  metadata: metadata
                )
              when :reduce
                Ops::Reduce.new(result: result, fn: attrs[:fn], arg: inputs.first, over_axes: attrs[:over_axes], axes: metadata[:axes] || instr.axes, dtype: metadata[:dtype] || instr.dtype, metadata: metadata)
              when :fold
                Ops::Fold.new(result: result, fn: attrs[:fn], arg: inputs.first, axes: metadata[:axes] || instr.axes, dtype: metadata[:dtype] || instr.dtype, metadata: metadata)
              when :make_object
                Ops::MakeObject.new(result: result, inputs: inputs, keys: attrs[:keys], axes: metadata[:axes] || instr.axes, dtype: metadata[:dtype] || instr.dtype, metadata: metadata)
              when :array_build
                Ops::ArrayBuild.new(result: result, elements: inputs, axes: metadata[:axes] || instr.axes, dtype: metadata[:dtype] || instr.dtype, metadata: metadata)
              when :array_get
                Ops::ArrayGet.new(result: result, array: inputs[0], index: inputs[1], oob: attrs[:oob], axes: metadata[:axes] || instr.axes, dtype: metadata[:dtype] || instr.dtype, metadata: metadata)
              when :array_len
                Ops::ArrayLen.new(result: result, array: inputs.first, axes: metadata[:axes] || instr.axes, dtype: metadata[:dtype] || instr.dtype, metadata: metadata)
              when :axis_index
                Ops::AxisIndex.new(result: result, axis: attrs[:axis], axes: metadata[:axes] || instr.axes, dtype: metadata[:dtype] || instr.dtype, metadata: metadata)
              when :axis_shift
                Ops::AxisShift.new(result: result, source: inputs.first, axis: attrs[:axis], offset: attrs[:offset], policy: attrs[:policy], axes: metadata[:axes] || instr.axes, dtype: metadata[:dtype] || instr.dtype, metadata: metadata)
              when :axis_broadcast
                Ops::AxisBroadcast.new(result: result, value: inputs.first, from_axes: attrs[:from_axes], to_axes: attrs[:to_axes] || metadata[:axes] || instr.axes, axes: metadata[:axes] || instr.axes, dtype: metadata[:dtype] || instr.dtype, metadata: metadata)
              when :import_call
                Ops::ImportCall.new(result: result, fn_name: attrs[:fn_name], source_module: attrs[:source_module], args: inputs, mapping_keys: attrs[:mapping_keys], axes: metadata[:axes] || instr.axes, dtype: metadata[:dtype] || instr.dtype, metadata: metadata)
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
