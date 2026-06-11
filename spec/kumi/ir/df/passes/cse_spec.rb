# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::DF::Passes::CSE do
  let(:ops) { df_ops }
  let(:float) { ir_types.scalar(:float) }

  it "removes duplicated map instructions with identical inputs" do
    block = df_block(
      instructions: [
        ops::Constant.new(result: :v1, value: 1.0, axes: [], dtype: float, metadata: { axes: [], dtype: float }),
        ops::Constant.new(result: :v2, value: 2.0, axes: [], dtype: float, metadata: { axes: [], dtype: float }),
        ops::Map.new(result: :v3, fn: :"core.add", args: %i[v1 v2], axes: [], dtype: float, metadata: { axes: [], dtype: float }),
        ops::Map.new(result: :v4, fn: :"core.add", args: %i[v1 v2], axes: [], dtype: float, metadata: { axes: [], dtype: float }),
        ops::Map.new(result: :v5, fn: :"core.add", args: %i[v3 v4], axes: [], dtype: float, metadata: { axes: [], dtype: float })
      ]
    )
    graph = Kumi::IR::DF::Graph.new(name: :demo, functions: [df_function(name: :foo, blocks: [block])])

    optimized = described_class.new.run(graph:, context: {})
    instrs = optimized.fetch_function(:foo).entry_block.instructions

    expect(instrs.map(&:opcode)).to eq(%i[constant constant map map])
    expect(instrs.last.inputs).to eq(%i[v3 v3])
  end
end
