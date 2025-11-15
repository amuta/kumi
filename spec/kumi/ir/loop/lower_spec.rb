# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::Loop::Lower do
  let(:float) { ir_types.scalar(:float) }
  let(:plan_factory) do
    lambda do |tail_keys|
      {
        steps: [],
        loop_ixs: [0],
        loop_axes: [:items],
        axis_to_loop: { items: 0 },
        head_path_by_loop: { 0 => [[:input, :items]] },
        between_loops: {},
        last_loop_li: 0,
        tail_keys_after_last_loop: Array(tail_keys).map(&:to_sym),
        element_terminal: false
      }
    end
  end

  let(:plan_index) do
    {
      "items" => plan_factory.call([]),
      "items.item" => plan_factory.call([:item]),
      "items.item.price" => plan_factory.call(%i[item price]),
      "items.item.qty" => plan_factory.call(%i[item qty])
    }
  end

  it "translates DF instructions and expands reduces" do
    graph = Kumi::IR::DF::Graph.new(name: :demo)
    block = df_block
    function = df_function(name: :cart_total, blocks: [block])
    graph.add_function(function)
    builder = Kumi::IR::DF::Builder.new(ir_module: graph, function:)

    items = builder.load_input(
      result: :items,
      key: :items,
      axes: [],
      dtype: ir_types.array(ir_types.scalar(:hash)),
      plan_ref: "items"
    )
    entries = builder.load_field(
      result: :entry,
      object: items,
      field: :item,
      axes: %i[items],
      dtype: ir_types.scalar(:hash),
      plan_ref: "items.item"
    )
    price = builder.load_field(
      result: :price,
      object: entries,
      field: :price,
      axes: %i[items],
      dtype: float,
      plan_ref: "items.item.price"
    )
    qty = builder.load_field(
      result: :qty,
      object: entries,
      field: :qty,
      axes: %i[items],
      dtype: float,
      plan_ref: "items.item.qty"
    )
    builder.map(
      result: :product,
      fn: :"core.mul:numeric",
      args: %i[price qty],
      axes: %i[items],
      dtype: float
    )
    builder.reduce(
      result: :total,
      fn: :"agg.sum",
      arg: :product,
      axes: [],
      over_axes: %i[items],
      dtype: float
    )

    loop_module = described_class.new(df_module: graph, context: { precomputed_plan_by_fqn: plan_index }).call
    loop_fn = loop_module.fetch_function(:cart_total)
    instructions = loop_fn.entry_block.instructions

    opcodes = instructions.map(&:opcode)
    expect(opcodes.first).to eq(:load_input)
    expect(opcodes.last).to eq(:yield)
    expect(opcodes.count(:loop_start)).to eq(1)
    expect(opcodes.count(:loop_end)).to eq(1)

    loop_start_idx = instructions.index { _1.opcode == :loop_start }
    loop_end_idx = instructions.index { _1.opcode == :loop_end }
    declare_idx = instructions.index { _1.opcode == :declare_accumulator }
    accumulate_idx = instructions.index { _1.opcode == :accumulate }
    load_acc_idx = instructions.index { _1.opcode == :load_accumulator }

    expect(declare_idx).to be < loop_start_idx
    expect(accumulate_idx).to be > loop_start_idx
    expect(accumulate_idx).to be < loop_end_idx
    expect(load_acc_idx).to be > loop_end_idx

    loop_start = instructions[loop_start_idx]
    loop_end = instructions[loop_end_idx]
    expect(loop_start.inputs.first).to eq(:items)
    expect(loop_start.attributes[:axis]).to eq(:items)
    expect(loop_end.attributes[:loop_id]).to eq(loop_start.attributes[:loop_id])

    load_input = instructions.first
    expect(load_input.attributes[:plan_ref]).to eq("items")

    yield_instr = instructions.last
    expect(yield_instr.inputs).to eq([:total])
  end

  it "closes and reopens loops when reduction results feed later passes" do
    graph = Kumi::IR::DF::Graph.new(name: :demo)
    block = df_block
    function = df_function(name: :high_value_sum, blocks: [block])
    graph.add_function(function)
    builder = Kumi::IR::DF::Builder.new(ir_module: graph, function:)

    items = builder.load_input(
      result: :items,
      key: :items,
      axes: [],
      dtype: ir_types.array(ir_types.scalar(:hash)),
      plan_ref: "items"
    )
    entry_first = builder.load_field(
      result: :entry_first,
      object: items,
      field: :item,
      axes: %i[items],
      dtype: ir_types.scalar(:hash),
      plan_ref: "items.item"
    )
    value_first = builder.load_field(
      result: :value_first,
      object: entry_first,
      field: :value,
      axes: %i[items],
      dtype: float,
      plan_ref: "items.item.value"
    )
    builder.reduce(
      result: :total_value,
      fn: :"agg.sum",
      arg: :value_first,
      axes: [],
      over_axes: %i[items],
      dtype: float
    )

    half = builder.constant(result: :half_factor, value: 0.5, axes: [], dtype: float)
    builder.map(
      result: :half_total,
      fn: :"core.mul:numeric",
      args: %i[total_value half_factor],
      axes: [],
      dtype: float
    )

    entry_second = builder.load_field(
      result: :entry_second,
      object: items,
      field: :item,
      axes: %i[items],
      dtype: ir_types.scalar(:hash),
      plan_ref: "items.item"
    )
    value_second = builder.load_field(
      result: :value_second,
      object: entry_second,
      field: :value,
      axes: %i[items],
      dtype: float,
      plan_ref: "items.item.value"
    )
    half_axis = builder.axis_broadcast(
      result: :half_axis,
      value: :half_total,
      from_axes: [],
      to_axes: %i[items],
      dtype: float
    )
    builder.map(
      result: :is_high,
      fn: :"core.gt",
      args: %i[value_second half_axis],
      axes: %i[items],
      dtype: ir_types.scalar(:boolean)
    )
    zero = builder.constant(result: :zero, value: 0, axes: [], dtype: float)
    zero_axis = builder.axis_broadcast(
      result: :zero_axis,
      value: :zero,
      from_axes: [],
      to_axes: %i[items],
      dtype: float
    )
    builder.select(
      result: :masked_values,
      cond: :is_high,
      on_true: :value_second,
      on_false: :zero_axis,
      axes: %i[items],
      dtype: float
    )
    builder.reduce(
      result: :high_total,
      fn: :"agg.sum",
      arg: :masked_values,
      axes: [],
      over_axes: %i[items],
      dtype: float
    )

    loop_module = described_class.new(df_module: graph, context: { precomputed_plan_by_fqn: plan_index }).call
    loop_fn = loop_module.fetch_function(:high_value_sum)
    instructions = loop_fn.entry_block.instructions

    loop_start_indices = instructions.each_index.select { instructions[_1].opcode == :loop_start }
    expect(loop_start_indices.length).to eq(2)

    first_loop_end_idx = instructions.each_index.find { instructions[_1].opcode == :loop_end }
    expect(first_loop_end_idx).not_to be_nil
    expect(loop_start_indices.last).to be > first_loop_end_idx

    total_acc_name = :total_value_acc
    load_idx = instructions.each_index.find do |idx|
      instr = instructions[idx]
      instr.opcode == :load_accumulator && instr.inputs.first == total_acc_name
    end
    expect(load_idx).not_to be_nil
    expect(load_idx).to be < loop_start_indices.last
  end
end
