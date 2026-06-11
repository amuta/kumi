# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::Printer do
  it "prints functions, blocks, and instructions" do
    graph = Kumi::IR::DF::Graph.new(name: :demo)
    fn = Kumi::IR::DF::Function.new(name: :sum, blocks: [Kumi::IR::Base::Block.new(name: :entry)])
    graph.add_function(fn)
    builder = Kumi::IR::DF::Builder.new(ir_module: graph, function: fn)
    builder.load_input(result: :x, key: :x, axes: [], dtype: ir_types.scalar(:integer))
    builder.load_input(result: :y, key: :y, axes: [], dtype: ir_types.scalar(:integer))
    builder.map(result: :sum, fn: :"core.add", args: %i[x y], axes: [], dtype: ir_types.scalar(:integer))

    io = StringIO.new
    described_class.print(graph, io:)

    output = io.string
    expect(output).to include("function sum")
    expect(output).to include("%sum = map")
    expect(output).to include("[] -> integer")
  end
end
