# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::DF::Passes::StencilCSE do
  let(:ops) { df_ops }
  let(:dtype) { ir_types.scalar(:integer) }

  it "deduplicates repeated axis_shift instructions" do
    instructions = [
      ops::DeclRef.new(result: :v1, name: :a, axes: %i[rows col], dtype: dtype),
      ops::AxisShift.new(result: :v2, source: :v1, axis: :rows, offset: 1, policy: :zero, axes: %i[rows col], dtype: dtype),
      ops::AxisShift.new(result: :v3, source: :v1, axis: :rows, offset: 1, policy: :zero, axes: %i[rows col], dtype: dtype),
      ops::Map.new(result: :v4, fn: :"core.add", args: %i[v2 v3], axes: %i[rows col], dtype: dtype)
    ]

    block = df_block(instructions:)
    fn = df_function(name: :demo, blocks: [block])
    graph = Kumi::IR::DF::Graph.new(name: :demo_program, functions: [fn])

    optimized = described_class.new.run(graph:, context: {})
    instrs = optimized.fetch_function(:demo).entry_block.instructions

    expect(instrs.map(&:opcode)).to eq(%i[decl_ref axis_shift map])
    expect(instrs.last.inputs).to eq(%i[v2 v2])
  end
end
