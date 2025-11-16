# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::DF::Passes::TupleFoldCanonicalization do
  let(:int_type) { ir_types.scalar(:integer) }
  let(:tuple_type) { ir_types.tuple([int_type] * 2) }
  let(:registry) do
    double("Registry", function: Struct.new(:options).new({ tuple_fold_combiner: :"core.add" }))
  end

  it "replaces fold over array_build with chained maps" do
    graph = Kumi::IR::DF::Graph.new(name: :demo)
    function = Kumi::IR::DF::Function.new(name: :foo, blocks: [Kumi::IR::Base::Block.new(name: :entry)])
    graph.add_function(function)
    builder = Kumi::IR::DF::Builder.new(ir_module: graph, function:)

    a = builder.load_input(result: :a, key: :a, axes: %i[rows], dtype: int_type)
    b = builder.load_input(result: :b, key: :b, axes: %i[rows], dtype: int_type)
    tuple = builder.array_build(result: :neighbors, elements: [a, b], axes: %i[rows], dtype: tuple_type)
    sum = builder.reduce(result: :neighbor_sum, fn: :"agg.sum", arg: tuple, axes: %i[rows], over_axes: [], dtype: int_type)
    builder.map(result: :alive, fn: :"core.eq", args: [sum, b], axes: %i[rows], dtype: ir_types.scalar(:boolean))

    pass = described_class.new
    new_graph = pass.run(graph:, context: { registry: registry })
    rewritten = new_graph.fetch_function(:foo).entry_block.instructions

    opcodes = rewritten.map(&:opcode)
    expect(opcodes).not_to include(:reduce)
    expect(opcodes).not_to include(:array_build)

    sum_inputs = rewritten.last.inputs
    expect(sum_inputs.first).not_to eq(:neighbor_sum)
    expect(sum_inputs.first).not_to eq(:neighbors)
  end
end
