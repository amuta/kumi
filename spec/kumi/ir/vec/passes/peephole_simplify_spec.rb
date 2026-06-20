# frozen_string_literal: true

require "spec_helper"

# PeepholeSimplify collapses select(c, x, x) -> x and and/or(x, x) -> x. It must
# NOT collapse the TERMINAL instruction: a Vec function's result is its last
# result-bearing instruction, so dropping the terminal would silently make an
# earlier instruction (e.g. the condition) the result.
RSpec.describe Kumi::IR::Vec::Passes::PeepholeSimplify do
  let(:vec_module) { Kumi::IR::Vec::Module.new(name: :test) }
  let(:function) do
    Kumi::IR::Base::Function.new(name: :compute, blocks: [Kumi::IR::Base::Block.new(name: :entry)])
  end
  let(:builder) { Kumi::IR::Vec::Builder.new(ir_module: vec_module, function:) }
  let(:float_t) { ir_types.scalar(:float) }
  let(:bool_t) { ir_types.scalar(:boolean) }

  before { vec_module.add_function(function) }

  def run
    described_class.new.run(graph: vec_module, context: {}).fetch_function(:compute)
  end

  def terminal(function)
    function.entry_block.instructions.reverse.find(&:result)
  end

  it "collapses a NON-terminal select(c, x, x) into x" do
    x = builder.load_input(result: :x, key: :x, axes: %i[items], dtype: float_t)
    cond = builder.map(result: :c, fn: :"core.gt", args: [x, x], axes: %i[items], dtype: bool_t)
    builder.select(result: :picked, cond: cond, on_true: x, on_false: x, axes: %i[items], dtype: float_t)
    # downstream use so the select is not the terminal
    builder.map(result: :out, fn: :"core.add", args: [:picked, x], axes: %i[items], dtype: float_t)

    fn = run
    add = fn.entry_block.instructions.find { |i| i.attributes[:fn] == :"core.add" }
    expect(add.inputs).to eq(%i[x x]) # :picked collapsed to :x
    expect(fn.entry_block.instructions.map(&:opcode)).not_to include(:select)
  end

  it "keeps a TERMINAL select(c, x, x) so the result stays x, not the condition" do
    x = builder.load_input(result: :x, key: :x, axes: %i[items], dtype: float_t)
    cond = builder.map(result: :c, fn: :"core.gt", args: [x, x], axes: %i[items], dtype: bool_t)
    builder.select(result: :same, cond: cond, on_true: x, on_false: x, axes: %i[items], dtype: float_t)

    fn = run
    expect(terminal(fn).opcode).to eq(:select)
    expect(terminal(fn).result).to eq(:same)
  end

  it "keeps a TERMINAL and(x, x) rather than dropping it" do
    a = builder.load_input(result: :a, key: :a, axes: %i[items], dtype: bool_t)
    builder.map(result: :both, fn: :"core.and", args: [a, a], axes: %i[items], dtype: bool_t)

    fn = run
    expect(terminal(fn).opcode).to eq(:map)
    expect(terminal(fn).result).to eq(:both)
  end
end
