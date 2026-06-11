# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::Vec::Module do
  let(:int_type) { ir_types.scalar(:integer) }

  it "converts DFIR functions into VecIR" do
    graph = Kumi::IR::DF::Graph.new(name: :demo)
    function = Kumi::IR::DF::Function.new(name: :neighbors, blocks: [Kumi::IR::Base::Block.new(name: :entry)])
    graph.add_function(function)
    builder = Kumi::IR::DF::Builder.new(ir_module: graph, function: function)

    alive = builder.load_input(result: :alive, key: :alive, axes: %i[row col], dtype: int_type)
    north = builder.axis_shift(result: :north, source: alive, axis: :row, offset: -1, policy: :zero, axes: %i[row col], dtype: int_type, metadata: {})
    sum = builder.map(result: :sum, fn: :"core.add", args: [alive, north], axes: %i[row col], dtype: int_type, metadata: {})
    builder.make_object(result: :cell, inputs: [sum], keys: [:value], axes: %i[row col], dtype: ir_types.scalar(:hash), metadata: {})

    vec_module = described_class.from_df(graph)
    vec_fn = vec_module.fetch_function(:neighbors)
    opcodes = vec_fn.entry_block.instructions.map(&:opcode)
    expect(opcodes).to eq(%i[load_input axis_shift map make_object])
  end
end
