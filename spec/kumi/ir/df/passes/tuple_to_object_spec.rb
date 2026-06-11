# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::DF::Passes::TupleToObject do
  let(:int_type) { ir_types.scalar(:integer) }
  let(:tuple_type) { ir_types.tuple([int_type, int_type, int_type]) }

  it "rewrites tuple array builds into make_object" do
    graph = Kumi::IR::DF::Graph.new(name: :demo)
    function = Kumi::IR::DF::Function.new(name: :scores, blocks: [Kumi::IR::Base::Block.new(name: :entry)])
    graph.add_function(function)
    builder = Kumi::IR::DF::Builder.new(ir_module: graph, function:)

    a = builder.constant(result: :a, value: 1, axes: [], dtype: int_type)
    b = builder.constant(result: :b, value: 2, axes: [], dtype: int_type)
    c = builder.constant(result: :c, value: 3, axes: [], dtype: int_type)
    builder.array_build(result: :tuple, elements: [a, b, c], axes: [], dtype: tuple_type)

    pass = described_class.new
    new_graph = pass.run(graph:, context: {})
    instructions = new_graph.fetch_function(:scores).entry_block.instructions
    expect(instructions.last.opcode).to eq(:make_object)
    expect(instructions.last.attributes[:keys]).to eq(%i[_0 _1 _2])
  end
end
