# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::Vec::Builder do
  let(:vec_module) { Kumi::IR::Vec::Module.new(name: :demo) }
  let(:function) do
    Kumi::IR::Base::Function.new(
      name: :compute,
      blocks: [Kumi::IR::Base::Block.new(name: :entry)]
    )
  end
  let(:builder) { described_class.new(ir_module: vec_module, function:) }
  let(:scalar) { ir_types.scalar(:integer) }

  before do
    vec_module.add_function(function)
  end

  it "builds elementwise instructions" do
    a = builder.load_input(result: :a, key: :a, axes: %i[rows], dtype: scalar)
    b = builder.load_input(result: :b, key: :b, axes: %i[rows], dtype: scalar)
    sum = builder.map(result: :sum, fn: :"core.add", args: [a, b], axes: %i[rows], dtype: scalar)

    expect(sum).to eq(:sum)
    opcodes = function.entry_block.instructions.map(&:opcode)
    expect(opcodes).to eq(%i[load_input load_input map])
  end

  it "records reduction metadata" do
    vec = builder.load_input(result: :vals, key: :vals, axes: %i[rows employees], dtype: scalar)
    builder.reduce(result: :row_sum, fn: :"agg.sum", arg: vec, axes: %i[rows], over_axes: %i[employees], dtype: scalar)

    reduce = function.entry_block.instructions.last
    expect(reduce.opcode).to eq(:reduce)
    expect(reduce.attributes[:over_axes]).to eq(%i[employees])
  end
end
