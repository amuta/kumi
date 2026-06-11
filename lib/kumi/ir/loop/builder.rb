# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      class Builder < Base::Builder
        def constant(result:, value:, axes: [], dtype: nil, metadata: {})
          append Ops::Constant.new(result:, value:, axes:, dtype:, metadata:)
        end

        def load_input(result:, key:, axes: [], dtype: nil, metadata: {})
          append Ops::LoadInput.new(result:, key:, axes:, dtype:, metadata:)
        end

        def load_field(result:, object:, field:, axes: [], dtype: nil, metadata: {})
          append Ops::LoadField.new(result:, object:, field:, axes:, dtype:, metadata:)
        end

        def kernel_call(result:, fn:, args:, axes: [], dtype: nil, metadata: {})
          append Ops::KernelCall.new(result:, fn:, args:, axes:, dtype:, metadata:)
        end

        def select(result:, cond:, on_true:, on_false:, axes: [], dtype: nil, metadata: {})
          append Ops::Select.new(result:, cond:, on_true:, on_false:, axes:, dtype:, metadata:)
        end

        def make_object(result:, inputs:, keys:, axes: [], dtype: nil, metadata: {})
          append Ops::MakeObject.new(result:, inputs:, keys:, axes:, dtype:, metadata:)
        end

        def ref(result:, value:, axes: [], dtype: nil, metadata: {})
          append Ops::Ref.new(result:, value:, axes:, dtype:, metadata:)
        end

        def loop_start(result:, source:, axis:, index:, metadata: {})
          append Ops::LoopStart.new(result:, source:, axis:, index:, metadata:)
        end

        def loop_end(axis:, metadata: {})
          append Ops::LoopEnd.new(axis:, metadata:)
        end

        def array_init(result:, metadata: {})
          append Ops::ArrayInit.new(result:, metadata:)
        end

        def array_push(array:, value:, metadata: {})
          append Ops::ArrayPush.new(array:, value:, metadata:)
        end

        def array_len(result:, array:, metadata: {})
          append Ops::ArrayLen.new(result:, array:, metadata:)
        end

        def index_read(result:, array:, index:, axes: [], dtype: nil, metadata: {})
          append Ops::IndexRead.new(result:, array:, index:, axes:, dtype:, metadata:)
        end

        def shift_read(result:, array:, index:, length:, offset:, policy:, fill: nil, dtype: nil, metadata: {})
          append Ops::ShiftRead.new(result:, array:, index:, length:, offset:, policy:, fill:, dtype:, metadata:)
        end

        def acc_init(result:, fn:, init:, nil_init:, dtype: nil, metadata: {})
          append Ops::AccInit.new(result:, fn:, init:, nil_init:, dtype:, metadata:)
        end

        def acc_step(acc:, value:, fn:, nil_init:, metadata: {})
          append Ops::AccStep.new(acc:, value:, fn:, nil_init:, metadata:)
        end

        def acc_load(result:, acc:, dtype: nil, metadata: {})
          append Ops::AccLoad.new(result:, acc:, dtype:, metadata:)
        end

        private

        def append(node)
          current_block.append(node)
          node.result
        end
      end
    end
  end
end
