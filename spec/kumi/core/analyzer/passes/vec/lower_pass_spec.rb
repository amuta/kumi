# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Analyzer::Passes::Vec::LowerPass do
  it "emits Vec modules and stores them in state" do
    df_module = build_df_module
    state = Kumi::Core::Analyzer::AnalysisState.new(df_module:)

    pass = described_class.new(nil, state)
    new_state = pass.run([])

    vec_module = new_state[:vec_module]
    expect(vec_module).to be_a(Kumi::IR::Vec::Module)
    fn = vec_module.fetch_function(:cart_total)
    expect(fn.entry_block.instructions.map(&:opcode)).to include(:map)
  end

  def build_df_module
    graph = Kumi::IR::DF::Graph.new(name: :demo)
    block = Kumi::IR::Base::Block.new(name: :entry)
    function = Kumi::IR::DF::Function.new(name: :cart_total, blocks: [block])
    graph.add_function(function)
    builder = Kumi::IR::DF::Builder.new(ir_module: graph, function:)

    float = ir_types.scalar(:float)
    items = builder.load_input(
      result: :items,
      key: :items,
      axes: [],
      dtype: ir_types.array(ir_types.scalar(:hash)),
      plan_ref: "items"
    )
    entry = builder.load_field(
      result: :entry,
      object: items,
      field: :item,
      axes: %i[items],
      dtype: ir_types.scalar(:hash),
      plan_ref: "items.item"
    )
    builder.load_field(
      result: :price,
      object: entry,
      field: :price,
      axes: %i[items],
      dtype: float,
      plan_ref: "items.item.price"
    )
    builder.load_field(
      result: :qty,
      object: entry,
      field: :qty,
      axes: %i[items],
      dtype: float,
      plan_ref: "items.item.qty"
    )
    builder.map(
      result: :total,
      fn: :"core.mul:numeric",
      args: %i[price qty],
      axes: %i[items],
      dtype: float
    )

    graph
  end
end
