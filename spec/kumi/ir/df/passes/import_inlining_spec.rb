# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::DF::Passes::ImportInlining do
  let(:ops) { df_ops }
  let(:decimal) { ir_types.scalar(:decimal) }
  let(:float) { ir_types.scalar(:float) }

  class FakeLoader
    def initialize(functions)
      @functions = functions.transform_keys(&:to_sym)
    end

    def function(name)
      @functions[name.to_sym]
    end
  end

  def build_callee_function
    block = df_block(
      instructions: [
        ops::LoadInput.new(result: :a, key: :amount, chain: ["amount"], plan_ref: "amount", axes: [], dtype: decimal, metadata: { axes: [], dtype: decimal }),
        ops::Constant.new(result: :c, value: 0.15, axes: [], dtype: float, metadata: { axes: [], dtype: float }),
        ops::Map.new(result: :out, fn: :"core.mul:numeric", args: %i[a c], axes: [], dtype: float, metadata: { axes: [], dtype: float })
      ]
    )
    df_function(name: :tax, blocks: [block])
  end

  it "replaces import_call instructions with the callee body when metadata is available" do
    callee_fn = build_callee_function
    loader = FakeLoader.new(tax: callee_fn)
    pass = described_class.new(loader:)

    fn_block = df_block(
      instructions: [
        ops::LoadInput.new(result: :v1, key: :items, chain: ["amount"], plan_ref: "items", axes: %i[items], dtype: decimal, metadata: { axes: %i[items], dtype: decimal }),
        ops::ImportCall.new(
          result: :v2,
          fn_name: :tax,
          source_module: "Tax",
          args: [:v1],
          mapping_keys: [:amount],
          axes: %i[items],
          dtype: float,
          metadata: { axes: %i[items], dtype: float }
        )
      ]
    )
    graph = Kumi::IR::DF::Graph.new(name: :demo, functions: [df_function(name: :item_taxes, blocks: [fn_block])])

    optimized = pass.run(graph:, context: {})
    instrs = optimized.fetch_function(:item_taxes).entry_block.instructions

    expect(instrs.map(&:opcode)).to eq(%i[load_input constant map])
    expect(instrs.last.inputs).to eq(%i[v1 v3])
    expect(instrs.last.axes).to eq(%i[items])
  end


  it "keeps import_call when loader cannot resolve callee" do
    pass = described_class.new(loader: FakeLoader.new({}))
    fn_block = df_block(
      instructions: [
        ops::ImportCall.new(
          result: :r,
          fn_name: :missing,
          source_module: "Tax",
          args: [],
          mapping_keys: [],
          axes: [],
          dtype: float,
          metadata: { axes: [], dtype: float }
        )
      ]
    )
    graph = Kumi::IR::DF::Graph.new(name: :demo, functions: [df_function(name: :foo, blocks: [fn_block])])

    optimized = pass.run(graph:, context: {})
    instrs = optimized.fetch_function(:foo).entry_block.instructions
    expect(instrs.map(&:opcode)).to eq([:import_call])
  end
end
