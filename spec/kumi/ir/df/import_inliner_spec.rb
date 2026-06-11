# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::DF::ImportInliner do
  let(:dtype) { ir_types.scalar(:integer) }
  let(:ops) { df_ops }

  it "remaps axes and axis-bearing attributes across a function" do
    instructions = [
      ops::DeclRef.new(result: :v1, name: :a, axes: %i[rows col], dtype: dtype),
      ops::AxisShift.new(result: :v2, source: :v1, axis: :rows, offset: 1, policy: :zero, axes: %i[rows col], dtype: dtype),
      ops::AxisBroadcast.new(result: :v3, value: :v2, from_axes: %i[rows], to_axes: %i[rows col], axes: %i[rows col], dtype: dtype),
      ops::Reduce.new(result: :v4, fn: :"agg.sum", arg: :v3, over_axes: %i[col], axes: %i[rows], dtype: dtype)
    ]

    fn = df_function(name: :demo, blocks: [df_block(instructions:)])

    inliner = described_class.new(axis_map: { rows: :orders, col: :items })
    remapped = inliner.remap_function(fn)

    instrs = remapped.entry_block.instructions

    expect(instrs[0].axes).to eq(%i[orders items])
    expect(instrs[1].attributes[:axis]).to eq(:orders)
    expect(instrs[1].axes).to eq(%i[orders items])
    expect(instrs[2].attributes[:from_axes]).to eq(%i[orders])
    expect(instrs[2].attributes[:to_axes]).to eq(%i[orders items])
    expect(instrs[3].attributes[:over_axes]).to eq(%i[items])
    expect(instrs[3].axes).to eq([:orders])
  end
end
