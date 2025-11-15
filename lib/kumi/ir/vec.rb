# frozen_string_literal: true

module Kumi
  module IR
    module Vec
      autoload :Ops, "kumi/ir/vec/ops"

      class Instruction < Base::Instruction
        def vector_width
          attributes[:width]
        end

        def mask?
          attributes[:mask] == true
        end
      end

      class Function < Base::Function; end

      class Module < Base::Module; end

      class Builder < Base::Builder
        def constant(result:, value:, axes:, dtype:, metadata: {})
          append Ops::Constant.new(result:, value:, axes:, dtype:, metadata:)
        end

        def load_input(result:, key:, axes:, dtype:, chain: [], metadata: {})
          append Ops::LoadInput.new(result:, key:, axes:, dtype:, chain:, metadata:)
        end

        def load_field(result:, object:, field:, axes:, dtype:, metadata: {})
          append Ops::LoadField.new(result:, object:, field:, axes:, dtype:, metadata:)
        end

        def map(result:, fn:, args:, axes:, dtype:, metadata: {})
          append Ops::Map.new(result:, fn:, args:, axes:, dtype:, metadata:)
        end

        def select(result:, cond:, on_true:, on_false:, axes:, dtype:, metadata: {})
          append Ops::Select.new(result:, cond:, on_true:, on_false:, axes:, dtype:, metadata:)
        end

        def axis_broadcast(result:, value:, from_axes:, to_axes:, dtype:, metadata: {})
          append Ops::AxisBroadcast.new(result:, value:, from_axes:, to_axes:, axes: to_axes, dtype:, metadata:)
        end

        def axis_shift(result:, source:, axis:, offset:, policy:, axes:, dtype:, metadata: {})
          append Ops::AxisShift.new(result:, source:, axis:, offset:, policy:, axes:, dtype:, metadata:)
        end

        def axis_index(result:, axis:, axes:, dtype:, metadata: {})
          append Ops::AxisIndex.new(result:, axis:, axes:, dtype:, metadata:)
        end

        def reduce(result:, fn:, arg:, axes:, over_axes:, dtype:, metadata: {})
          append Ops::Reduce.new(result:, fn:, arg:, axes:, over_axes:, dtype:, metadata:)
        end

        def fold(result:, fn:, arg:, axes:, dtype:, metadata: {})
          append Ops::Fold.new(result:, fn:, arg:, axes:, dtype:, metadata:)
        end

        def array_build(result:, elements:, axes:, dtype:, metadata: {})
          append Ops::ArrayBuild.new(result:, elements:, axes:, dtype:, metadata:)
        end

        def decl_ref(result:, name:, axes:, dtype:, metadata: {})
          append Ops::DeclRef.new(result:, name:, axes:, dtype:, metadata:)
        end

        def import_call(result:, fn_name:, source_module:, args:, mapping_keys:, axes:, dtype:, metadata: {})
          append Ops::ImportCall.new(result:, fn_name:, source_module:, args:, mapping_keys:, axes:, dtype:, metadata:)
        end

        def make_object(result:, inputs:, keys:, axes:, dtype:, metadata: {})
          append Ops::MakeObject.new(result:, inputs:, keys:, axes:, dtype:, metadata:)
        end

        private

        def instruction_class
          Instruction
        end

        def append(node)
          current_block.append(node)
          node.result
        end
      end
    end
  end
end
