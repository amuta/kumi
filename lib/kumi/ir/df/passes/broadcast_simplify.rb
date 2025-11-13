# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Passes
        class BroadcastSimplify < Kumi::IR::Passes::Base
          def run(graph:, context: {})
            functions = graph.functions.values.map { |fn| rewrite_function(fn) }
            Kumi::IR::DF::Graph.new(name: graph.name, functions: functions)
          end

          private

          def rewrite_function(fn)
            new_blocks = fn.blocks.map { |block| rewrite_block(block) }
            Kumi::IR::DF::Function.new(
              name: fn.name,
              parameters: fn.parameters,
              blocks: new_blocks,
              return_stamp: fn.return_stamp
            )
          end

          def rewrite_block(block)
            replacements = {}
            axes_by_reg = {}
            new_instructions = []

            block.each do |instr|
              new_inputs = instr.inputs.map { |reg| canonical_reg(reg, replacements) }

              if removable_broadcast?(instr, new_inputs, axes_by_reg)
                replacements[instr.result] = new_inputs.first
                next
              end

              cloned = clone_instruction(instr, new_inputs)
              new_instructions << cloned
              axes_by_reg[cloned.result] = cloned.axes if cloned.result
            end

            Kumi::IR::Base::Block.new(name: block.name, instructions: new_instructions)
          end

          def removable_broadcast?(instr, inputs, axes_by_reg)
            return false unless instr.opcode == :axis_broadcast

            src = inputs.first
            src_axes = axes_by_reg[src]
            return false unless src_axes

            src_axes == instr.axes
          end

          def canonical_reg(reg, replacements)
            seen = []
            while replacements.key?(reg) && !seen.include?(reg)
              seen << reg
              reg = replacements[reg]
            end
            reg
          end

          def clone_instruction(instr, inputs)
            metadata = instr.metadata || { dtype: instr.dtype, axes: instr.axes }
            attrs = instr.attributes || {}

            case instr.opcode
            when :load_input
              Ops::LoadInput.new(
                result: instr.result,
                key: attrs[:key],
                chain: attrs[:chain] || [],
                plan_ref: attrs[:plan_ref],
                axes: instr.axes,
                dtype: instr.dtype,
                metadata: metadata
              )
            when :load_field
              Ops::LoadField.new(
                result: instr.result,
                object: inputs.first,
                field: attrs[:field],
                axes: instr.axes,
                dtype: instr.dtype,
                metadata: metadata
              )
            when :constant
              Ops::Constant.new(result: instr.result, value: attrs[:value], axes: instr.axes, dtype: instr.dtype, metadata: metadata)
            when :decl_ref
              Ops::DeclRef.new(result: instr.result, name: attrs[:name], axes: instr.axes, dtype: instr.dtype, metadata: metadata)
            when :map
              Ops::Map.new(result: instr.result, fn: attrs[:fn], args: inputs, axes: instr.axes, dtype: instr.dtype, metadata: metadata)
            when :select
              Ops::Select.new(
                result: instr.result,
                cond: inputs[0],
                on_true: inputs[1],
                on_false: inputs[2],
                axes: instr.axes,
                dtype: instr.dtype,
                metadata: metadata
              )
            when :reduce
              Ops::Reduce.new(result: instr.result, fn: attrs[:fn], arg: inputs.first, over_axes: attrs[:over_axes], axes: instr.axes, dtype: instr.dtype, metadata: metadata)
            when :fold
              Ops::Fold.new(result: instr.result, fn: attrs[:fn], arg: inputs.first, axes: instr.axes, dtype: instr.dtype, metadata: metadata)
            when :make_object
              Ops::MakeObject.new(result: instr.result, inputs: inputs, keys: attrs[:keys], axes: instr.axes, dtype: instr.dtype, metadata: metadata)
            when :array_build
              Ops::ArrayBuild.new(result: instr.result, elements: inputs, axes: instr.axes, dtype: instr.dtype, metadata: metadata)
            when :array_get
              Ops::ArrayGet.new(result: instr.result, array: inputs[0], index: inputs[1], oob: attrs[:oob], axes: instr.axes, dtype: instr.dtype, metadata: metadata)
            when :array_len
              Ops::ArrayLen.new(result: instr.result, array: inputs.first, axes: instr.axes, dtype: instr.dtype, metadata: metadata)
            when :axis_index
              Ops::AxisIndex.new(result: instr.result, axis: attrs[:axis], axes: instr.axes, dtype: instr.dtype, metadata: metadata)
            when :axis_shift
              Ops::AxisShift.new(result: instr.result, source: inputs.first, axis: attrs[:axis], offset: attrs[:offset], policy: attrs[:policy], axes: instr.axes, dtype: instr.dtype, metadata: metadata)
            when :axis_broadcast
              Ops::AxisBroadcast.new(result: instr.result, value: inputs.first, from_axes: attrs[:from_axes], to_axes: attrs[:to_axes] || instr.axes, axes: instr.axes, dtype: instr.dtype, metadata: metadata)
            when :import_call
              Ops::ImportCall.new(result: instr.result, fn_name: attrs[:fn_name], source_module: attrs[:source_module], args: inputs, mapping_keys: attrs[:mapping_keys], axes: instr.axes, dtype: instr.dtype, metadata: metadata)
            else
              instr
            end
          end
        end
      end
    end
  end
end
