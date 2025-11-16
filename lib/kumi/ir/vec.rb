# frozen_string_literal: true

module Kumi
  module IR
    module Vec
      autoload :Ops, "kumi/ir/vec/ops"
      autoload :Passes, "kumi/ir/vec/passes"
      autoload :Pipeline, "kumi/ir/vec/pipeline"
      autoload :Lower, "kumi/ir/vec/lower"
      autoload :Validator, "kumi/ir/vec/validator"

      class Function < Base::Function; end

      class Module < Base::Module
        def self.from_df(df_module, context: {})
          Lower.new(df_module: df_module).call
        end
      end

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
          append Ops::AxisBroadcast.new(result:, value:, from_axes:, to_axes:, dtype:, metadata:)
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

        private

        def append(node)
          current_block.append(node)
          node.result
        end
      end
    end
  end
end
