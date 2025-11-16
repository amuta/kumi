# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::Vec::Pipeline do
  let(:vec_module) { Kumi::IR::Vec::Module.new(name: :game_of_life) }
  let(:function) do
    Kumi::IR::Base::Function.new(
      name: :neighbors,
      blocks: [Kumi::IR::Base::Block.new(name: :entry)]
    )
  end
  let(:builder) { Kumi::IR::Vec::Builder.new(ir_module: vec_module, function:) }
  let(:int_type) { ir_types.scalar(:integer) }

  before do
    vec_module.add_function(function)
  end

  it "runs the default pipeline and keeps VecIR tuple-free" do
    base = builder.load_input(result: :base, key: :alive, axes: %i[rows col], dtype: int_type)
    north = builder.axis_shift(result: :north, source: base, axis: :rows, offset: -1, policy: :zero, axes: %i[rows col], dtype: int_type, metadata: {})
    south = builder.axis_shift(result: :south, source: base, axis: :rows, offset: 1, policy: :zero, axes: %i[rows col], dtype: int_type, metadata: {})
    east = builder.axis_shift(result: :east, source: base, axis: :col, offset: 1, policy: :zero, axes: %i[rows col], dtype: int_type, metadata: {})
    west = builder.axis_shift(result: :west, source: base, axis: :col, offset: -1, policy: :zero, axes: %i[rows col], dtype: int_type, metadata: {})

    builder.map(result: :sum1, fn: :"core.add", args: [north, south], axes: %i[rows col], dtype: int_type, metadata: {})
    builder.select(result: :alive, cond: base, on_true: east, on_false: west, axes: %i[rows col], dtype: int_type, metadata: {})

    optimized = described_class.run(graph: vec_module, context: {})
    fn = optimized.fetch_function(:neighbors)
    opcodes = fn.entry_block.instructions.map(&:opcode)
    expect(opcodes).to include(:select)
    expect(opcodes).not_to include(:fold)
  end
end
