# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::DF::Pipeline do
  it "handles graphs with no functions" do
    graph = Kumi::IR::DF::Graph.new(name: :demo)
    optimized = described_class.run(graph:, context: {})
    expect(optimized.functions).to be_empty
  end

  it "removes redundant axis broadcasts" do
    dtype = ir_types.scalar(:integer)
    const = Kumi::IR::DF::Ops::Constant.new(result: :v1, value: 1, axes: [], dtype: dtype)
    broadcast = Kumi::IR::DF::Ops::AxisBroadcast.new(result: :v2, value: :v1, from_axes: [], to_axes: [], axes: [], dtype: dtype)
    map = Kumi::IR::DF::Ops::Map.new(result: :v3, fn: :"core.identity", args: [:v2], axes: [], dtype: dtype)

    block = Kumi::IR::Base::Block.new(name: :entry, instructions: [const, broadcast, map])
    function = Kumi::IR::DF::Function.new(name: :foo, blocks: [block])
    graph = Kumi::IR::DF::Graph.new(name: :demo, functions: [function])

    optimized = described_class.run(graph:, context: {})
    instrs = optimized.fetch_function(:foo).entry_block.instructions
    expect(instrs.map(&:opcode)).not_to include(:axis_broadcast)
    expect(instrs.last.inputs.first).to eq(:v1)
  end

  it "runs TupleToObject after import inlining" do
    pass_classes = described_class.default_passes.map(&:class)
    tuple_idx = pass_classes.index(Kumi::IR::DF::Passes::TupleToObject)
    import_idx = pass_classes.index(Kumi::IR::DF::Passes::ImportInlining)

    expect(tuple_idx).to be > import_idx
  end
end
