# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::DF::Passes::DeclInlining do
  let(:ops) { df_ops }
  let(:int) { ir_types.scalar(:integer) }

  it "replaces decl_ref instructions with cloned bodies" do
    callee_block = df_block(
      instructions: [
        ops::Constant.new(result: :v1, value: 1, axes: [], dtype: int, metadata: { axes: [], dtype: int }),
        ops::Constant.new(result: :v2, value: 2, axes: [], dtype: int, metadata: { axes: [], dtype: int }),
        ops::Map.new(result: :v3, fn: :"core.add", args: %i[v1 v2], axes: [], dtype: int, metadata: { axes: [], dtype: int })
      ]
    )
    main_block = df_block(
      instructions: [
        ops::DeclRef.new(result: :ref, name: :helper, axes: [], dtype: int, metadata: { axes: [], dtype: int }),
        ops::Map.new(result: :result, fn: :"core.add", args: %i[ref ref], axes: [], dtype: int, metadata: { axes: [], dtype: int })
      ]
    )

    helper_fn = df_function(name: :helper, blocks: [callee_block])
    main_fn = df_function(name: :total, blocks: [main_block])
    graph = Kumi::IR::DF::Graph.new(name: :demo, functions: [helper_fn, main_fn])

    optimized = described_class.new.run(graph:, context: {})
    instrs = optimized.fetch_function(:total).entry_block.instructions

    expect(instrs.map(&:opcode)).to eq(%i[constant constant map map])
  end

  it "avoids infinite recursion on cyclical declarations" do
    block_a = df_block(
      instructions: [
        ops::DeclRef.new(result: :r1, name: :b, axes: [], dtype: int, metadata: { axes: [], dtype: int })
      ]
    )
    block_b = df_block(
      instructions: [
        ops::DeclRef.new(result: :r2, name: :a, axes: [], dtype: int, metadata: { axes: [], dtype: int })
      ]
    )

    fn_a = df_function(name: :a, blocks: [block_a])
    fn_b = df_function(name: :b, blocks: [block_b])
    graph = Kumi::IR::DF::Graph.new(name: :demo, functions: [fn_a, fn_b])

    optimized = described_class.new.run(graph:, context: {})
    instrs = optimized.fetch_function(:a).entry_block.instructions
    expect(instrs.map(&:opcode)).to eq([:decl_ref])
  end
end
