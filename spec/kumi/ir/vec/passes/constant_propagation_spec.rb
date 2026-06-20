# frozen_string_literal: true

require "spec_helper"

# ConstantPropagation folds all-constant ops and, additionally, removes
# algebraic-identity ops (x*1, x/1, x-0, and integer x+0 / x*0) when doing so
# is exact for the dtype under IEEE 754. It never touches the terminal
# instruction, which defines the function's result.
RSpec.describe Kumi::IR::Vec::Passes::ConstantPropagation do
  let(:vec_module) { Kumi::IR::Vec::Module.new(name: :test) }
  let(:function) do
    Kumi::IR::Base::Function.new(name: :compute, blocks: [Kumi::IR::Base::Block.new(name: :entry)])
  end
  let(:builder) { Kumi::IR::Vec::Builder.new(ir_module: vec_module, function:) }
  let(:float_t) { ir_types.scalar(:float) }
  let(:int_t) { ir_types.scalar(:integer) }

  before { vec_module.add_function(function) }

  def run
    described_class.new.run(graph: vec_module, context: {}).fetch_function(:compute)
  end

  def opcodes(function) = function.entry_block.instructions.map(&:opcode)

  # x * 1.0 used downstream: the multiply is gone and the consumer reads x.
  def build_identity(fn_id:, dtype:, const_value:)
    x = builder.load_input(result: :x, key: :x, axes: %i[items], dtype: dtype)
    one = builder.constant(result: :one, value: const_value, axes: [], dtype: dtype)
    b = builder.axis_broadcast(result: :one_b, value: one, from_axes: [], to_axes: %i[items], dtype: dtype)
    builder.map(result: :ident, fn: fn_id, args: [x, b], axes: %i[items], dtype: dtype)
    # downstream consumer so :ident is not the terminal
    builder.map(result: :out, fn: :"core.add", args: [:ident, x], axes: %i[items], dtype: dtype)
  end

  it "removes x * 1.0 and rewrites the consumer to read x" do
    build_identity(fn_id: :"core.mul:numeric", dtype: float_t, const_value: 1.0)
    fn = run

    expect(opcodes(fn).count(:map)).to eq(1) # only the downstream add survives
    add = fn.entry_block.instructions.find { |i| i.attributes[:fn] == :"core.add" }
    expect(add.inputs).to eq(%i[x x]) # :ident became :x
  end

  it "removes x / 1.0 (float, always safe)" do
    build_identity(fn_id: :"core.div", dtype: float_t, const_value: 1.0)
    fn = run
    add = fn.entry_block.instructions.find { |i| i.attributes[:fn] == :"core.add" }
    expect(add.inputs).to eq(%i[x x])
  end

  it "removes x - 0.0 (float, always safe)" do
    build_identity(fn_id: :"core.sub", dtype: float_t, const_value: 0.0)
    fn = run
    add = fn.entry_block.instructions.find { |i| i.attributes[:fn] == :"core.add" }
    expect(add.inputs).to eq(%i[x x])
  end

  it "removes integer x + 0" do
    build_identity(fn_id: :"core.add", dtype: int_t, const_value: 0)
    fn = run
    add = fn.entry_block.instructions.find { |i| i.inputs == %i[x x] }
    expect(add).not_to be_nil
  end

  it "removes integer x * 0, leaving the zero in its place" do
    build_identity(fn_id: :"core.mul:numeric", dtype: int_t, const_value: 0)
    fn = run
    # :ident becomes the broadcast-zero register; the downstream add reads it.
    add = fn.entry_block.instructions.find { |i| i.attributes[:fn] == :"core.add" }
    expect(add.inputs).to eq(%i[one_b x])
  end

  it "does NOT fold float x * 0.0 (Infinity*0 = NaN under IEEE 754)" do
    build_identity(fn_id: :"core.mul:numeric", dtype: float_t, const_value: 0.0)
    fn = run

    expect(opcodes(fn).count(:map)).to eq(2) # the multiply survives
    mul = fn.entry_block.instructions.find { |i| i.attributes[:fn] == :"core.mul:numeric" }
    expect(mul).not_to be_nil
  end

  it "does NOT fold float x + 0.0 (would drop a -0.0 sign)" do
    build_identity(fn_id: :"core.add", dtype: float_t, const_value: 0.0)
    fn = run

    # both maps survive (the identity add and the consumer add)
    expect(opcodes(fn).count(:map)).to eq(2)
  end

  it "does not simplify the terminal instruction (it defines the result)" do
    x = builder.load_input(result: :x, key: :x, axes: %i[items], dtype: float_t)
    one = builder.constant(result: :one, value: 1.0, axes: [], dtype: float_t)
    b = builder.axis_broadcast(result: :one_b, value: one, from_axes: [], to_axes: %i[items], dtype: float_t)
    builder.map(result: :out, fn: :"core.mul:numeric", args: [x, b], axes: %i[items], dtype: float_t)

    fn = run
    expect(fn.entry_block.instructions.last.attributes[:fn]).to eq(:"core.mul:numeric")
  end
end
