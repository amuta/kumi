# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::DF::Validator do
  let(:int_type) { ir_types.scalar(:integer) }

  def graph_with(*instructions)
    block = df_block(instructions:)
    fn = df_function(name: :demo, blocks: [block])
    Kumi::IR::DF::Graph.new(name: :demo, functions: [fn])
  end

  it "rejects load_input instructions that mix plan_ref and traversal chain" do
    graph = graph_with(
      df_ops::LoadInput.new(
        result: :v1,
        key: :rows,
        chain: ["rows"],
        plan_ref: "rows",
        axes: [],
        dtype: int_type,
        metadata: { axes: [], dtype: int_type }
      )
    )

    expect { described_class.validate!(graph) }
      .to raise_error(ArgumentError, /load_input with plan_ref must be root-only/)
  end

  it "accepts root-only load_input instructions with plan_ref" do
    graph = graph_with(
      df_ops::LoadInput.new(
        result: :v1,
        key: :rows,
        chain: [],
        plan_ref: "rows",
        axes: [],
        dtype: int_type,
        metadata: { axes: [], dtype: int_type }
      )
    )

    expect(described_class.validate!(graph)).to eq(graph)
  end
end
