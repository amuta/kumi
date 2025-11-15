# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::Loop::Builder do
  let(:graph) { Kumi::IR::Loop::Module.new(name: :demo) }
  let(:function) do
    Kumi::IR::Loop::Function.new(
      name: :cart_total,
      blocks: [Kumi::IR::Base::Block.new(name: :entry)]
    )
  end
  let(:builder) { described_class.new(ir_module: graph, function: function) }
  let(:float) { ir_types.scalar(:float) }
  let(:int_type) { ir_types.scalar(:integer) }

  before do
    graph.add_function(function)
  end

  it "emits loop and accumulator instructions" do
    items = builder.load_input(result: :items, key: :items, plan_ref: "items", axes: [], dtype: Kumi::Core::Types.array(ir_types.scalar(:hash)))
    builder.loop_start(axis: :items, collection: items, element: :item_reg, index: :item_idx, loop_id: :L0)

    price = builder.load_field(result: :price, object: :item_reg, field: :price, plan_ref: "items.item.price", axes: %i[items], dtype: float)
    qty = builder.load_field(result: :qty, object: :item_reg, field: :qty, plan_ref: "items.item.qty", axes: %i[items], dtype: int_type)
    product = builder.map(result: :product, fn: :"core.mul:numeric", args: [price, qty], axes: %i[items], dtype: float)

    acc = builder.declare_accumulator(result: :acc, fn: :"agg.sum", axes: [], dtype: float)
    builder.accumulate(accumulator: acc, value: product)
    builder.loop_end(loop_id: :L0)

    total = builder.load_accumulator(result: :total, accumulator: acc, axes: [], dtype: float)
    builder.yield(values: [total])

    opcodes = function.entry_block.instructions.map(&:opcode)
    expect(opcodes).to eq(%i[load_input loop_start load_field load_field map declare_accumulator accumulate loop_end load_accumulator yield])
  end
end
