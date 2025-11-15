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
    expect(output).to include("block entry")
    expect(output).to include("%sum = map")
    expect(output).to include("[] -> integer")
  end

  it "indents loop bodies" do
    loop_module = Kumi::IR::Loop::Module.new(name: :demo)
    fn = Kumi::IR::Loop::Function.new(name: :loop_fn, blocks: [Kumi::IR::Base::Block.new(name: :entry)])
    loop_module.add_function(fn)
    builder = Kumi::IR::Loop::Builder.new(ir_module: loop_module, function: fn)

    items = builder.load_input(
      result: :items,
      key: :items,
      plan_ref: "items",
      axes: [],
      dtype: ir_types.array(ir_types.scalar(:hash)),
      chain: [],
      metadata: {}
    )
    builder.loop_start(axis: :items, collection: items, element: :items_el, index: :items_idx, loop_id: :L1, metadata: {})
    builder.axis_index(result: :idx, axis: :items, axes: %i[items], dtype: ir_types.scalar(:integer), metadata: {})
    builder.loop_end(loop_id: :L1, metadata: {})

    io = StringIO.new
    described_class.print(loop_module, io:)
    lines = io.string.split("\n")
    loop_start_line = lines.find { |line| line.include?("loop_start") }
    inner_line = lines.find { |line| line.include?("axis_index") }
    expect(loop_start_line).to start_with("    loop_start")
    expect(inner_line).to start_with("      ")
  end
end
