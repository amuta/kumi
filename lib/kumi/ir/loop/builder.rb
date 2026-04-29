# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      class Builder < Base::Builder
        def constant(result:, value:, axes:, dtype:, metadata: {})
          append Ops::Constant.new(result:, value:, axes:, dtype:, metadata:)
        end

        def load_input(result:, key:, axes:, dtype:, chain: [], metadata: {})
          append Ops::LoadInput.new(result:, key:, chain:, axes:, dtype:, metadata:)
        end

        def load_field(result:, object:, field:, axes:, dtype:, metadata: {})
          append Ops::LoadField.new(result:, object:, field:, axes:, dtype:, metadata:)
        end

        def kernel_call(result:, fn:, args:, axes:, dtype:, metadata: {})
          append Ops::KernelCall.new(result:, fn:, args:, axes:, dtype:, metadata:)
        end

        def select(result:, cond:, on_true:, on_false:, axes:, dtype:, metadata: {})
          append Ops::Select.new(result:, cond:, on_true:, on_false:, axes:, dtype:, metadata:)
        end

        def make_object(result:, inputs:, keys:, axes:, dtype:, metadata: {})
          append Ops::MakeObject.new(result:, inputs:, keys:, axes:, dtype:, metadata:)
        end

        def reduce(result:, fn:, arg:, axes:, over_axes:, dtype:, metadata: {})
          append Ops::Reduce.new(result:, fn:, arg:, over_axes:, axes:, dtype:, metadata:)
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
