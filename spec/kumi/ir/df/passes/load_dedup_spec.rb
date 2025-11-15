# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::DF::Passes::LoadDedup do
  let(:ops) { df_ops }
  let(:float) { ir_types.scalar(:float) }

  it "reuses identical load_input and load_field instructions" do
    block = df_block(
      instructions: [
        ops::LoadInput.new(result: :v1, key: :items, chain: ["price"], plan_ref: "items", axes: %i[items], dtype: float, metadata: { axes: %i[items], dtype: float }),
        ops::LoadInput.new(result: :v2, key: :items, chain: ["price"], plan_ref: "items", axes: %i[items], dtype: float, metadata: { axes: %i[items], dtype: float }),
        ops::LoadField.new(result: :v3, object: :v1, field: :item, plan_ref: "items.item", axes: %i[items], dtype: float, metadata: { axes: %i[items], dtype: float }),
        ops::LoadField.new(result: :v4, object: :v1, field: :item, plan_ref: "items.item", axes: %i[items], dtype: float, metadata: { axes: %i[items], dtype: float }),
        ops::Map.new(result: :v5, fn: :"core.add", args: %i[v3 v4], axes: %i[items], dtype: float, metadata: { axes: %i[items], dtype: float })
      ]
    )
    graph = Kumi::IR::DF::Graph.new(name: :demo, functions: [df_function(name: :foo, blocks: [block])])

    optimized = described_class.new.run(graph:, context: {})
    instrs = optimized.fetch_function(:foo).entry_block.instructions

    expect(instrs.map(&:opcode)).to eq(%i[load_input load_field map])
    expect(instrs.last.inputs).to eq(%i[v3 v3])
  end
end
