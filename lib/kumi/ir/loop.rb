# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      autoload :Ops, "kumi/ir/loop/ops"
      autoload :Lower, "kumi/ir/loop/lower"
      autoload :Pipeline, "kumi/ir/loop/pipeline"

      OPCODES = %i[
        constant
        load_input
        load_field
        loop_start
        loop_end
        map
        select
        declare_accumulator
        accumulate
        load_accumulator
        axis_shift
        axis_broadcast
        array_build
        array_get
        array_len
        axis_index
        fold
        decl_ref
        import_call
        make_tuple
        make_object
        tuple_get
        yield
      ].freeze

      class Instruction < Base::Instruction
        def loop_control?
          %i[loop_start loop_end].include?(opcode)
        end

        def accumulator?
          %i[declare_accumulator accumulate load_accumulator].include?(opcode)
        end
      end

      class Function < Base::Function
        attr_reader :axes

        def initialize(axes: [], **kwargs)
          @axes = Array(axes).map(&:to_sym)
          super(**kwargs)
        end
      end

      class Module < Base::Module
        def self.from_dfir(df_graph, context: {})
          Lower.new(df_module: df_graph, context: context).call
        end
      end

      class Builder < Base::Builder
        def constant(result:, value:, dtype:, axes: [], metadata: {})
          append Ops::Constant.new(result:, value:, dtype:, axes:, metadata:)
        end

        def load_input(result:, key:, plan_ref:, axes:, dtype:, chain: [], metadata: {})
          append Ops::LoadInput.new(result:, key:, plan_ref:, axes:, dtype:, chain:, metadata:)
        end

        def load_field(result:, object:, field:, plan_ref:, axes:, dtype:, metadata: {})
          append Ops::LoadField.new(result:, object:, field:, plan_ref:, axes:, dtype:, metadata:)
        end

        def map(result:, fn:, args:, axes:, dtype:, metadata: {})
          append Ops::Map.new(result:, fn:, args:, axes:, dtype:, metadata:)
        end

        def select(result:, cond:, on_true:, on_false:, axes:, dtype:, metadata: {})
          append Ops::Select.new(result:, cond:, on_true:, on_false:, axes:, dtype:, metadata:)
        end

        def axis_shift(result:, source:, axis:, offset:, policy:, axes:, dtype:, metadata: {})
          append Ops::AxisShift.new(result:, source:, axis:, offset:, policy:, axes:, dtype:, metadata:)
        end

        def axis_broadcast(result:, value:, from_axes:, to_axes:, dtype:, metadata: {})
          append Ops::AxisBroadcast.new(result:, value:, from_axes:, to_axes:, axes: to_axes, dtype:, metadata:)
        end

        def array_build(result:, elements:, axes:, dtype:, metadata: {})
          append Ops::ArrayBuild.new(result:, elements:, axes:, dtype:, metadata:)
        end

        def array_get(result:, array:, index:, axes:, dtype:, oob:, metadata: {})
          append Ops::ArrayGet.new(result:, array:, index:, axes:, dtype:, oob:, metadata:)
        end

        def array_len(result:, array:, axes:, dtype:, metadata: {})
          append Ops::ArrayLen.new(result:, array:, axes:, dtype:, metadata:)
        end

        def axis_index(result:, axis:, axes:, dtype:, metadata: {})
          append Ops::AxisIndex.new(result:, axis:, axes:, dtype:, metadata:)
        end

        def fold(result:, fn:, arg:, axes:, dtype:, metadata: {})
          append Ops::Fold.new(result:, fn:, arg:, axes:, dtype:, metadata:)
        end

        def loop_start(axis:, collection:, element:, index:, loop_id:, metadata: {})
          append Ops::LoopStart.new(collection:, axis:, element:, index:, loop_id:, metadata:)
        end

        def loop_end(loop_id:, metadata: {})
          append Ops::LoopEnd.new(loop_id:, metadata:)
        end

        def declare_accumulator(result:, fn:, axes:, dtype:, metadata: {})
          append Ops::DeclareAccumulator.new(result:, fn:, axes:, dtype:, metadata:)
        end

        def accumulate(accumulator:, value:, metadata: {})
          append Ops::Accumulate.new(accumulator:, value:, metadata:)
        end

        def load_accumulator(result:, accumulator:, axes:, dtype:, metadata: {})
          append Ops::LoadAccumulator.new(result:, accumulator:, axes:, dtype:, metadata:)
        end

        def yield(values:, metadata: {})
          append Ops::Yield.new(values:, metadata:)
        end

        def decl_ref(result:, name:, axes:, dtype:, metadata: {})
          append Ops::DeclRef.new(result:, name:, axes:, dtype:, metadata:)
        end

        def import_call(result:, fn_name:, source_module:, args:, mapping_keys: [], axes:, dtype:, metadata: {})
          append Ops::ImportCall.new(result:, fn_name:, source_module:, args:, mapping_keys:, axes:, dtype:, metadata:)
        end

        def make_tuple(result:, elements:, axes:, dtype:, metadata: {})
          append Ops::MakeTuple.new(result:, elements:, axes:, dtype:, metadata:)
        end

        def make_object(result:, keys:, values:, axes:, dtype:, metadata: {})
          append Ops::MakeObject.new(result:, keys:, values:, axes:, dtype:, metadata:)
        end

        def tuple_get(result:, tuple:, index:, axes:, dtype:, metadata: {})
          append Ops::TupleGet.new(result:, tuple:, index:, axes:, dtype:, metadata:)
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
