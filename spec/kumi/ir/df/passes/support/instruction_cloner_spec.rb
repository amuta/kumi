# frozen_string_literal: true

require "spec_helper"

# Guards the "break loudly" contract: the DF InstructionCloner must have a clone
# branch for every opcode. A missing branch used to silently return the original
# instruction with stale inputs, corrupting register remapping in DF passes
# (dedup / inlining / CSE) and producing wrong results with no error.
RSpec.describe Kumi::IR::DF::Passes::Support::InstructionCloner do
  # Minimal instruction double carrying just what `clone` reads.
  let(:instr_struct) do
    Struct.new(:opcode, :uses, :defs, :attributes, :metadata, :dtype, :axes, :result, keyword_init: true)
  end

  def fake_instr(**attrs)
    instr_struct.new(
      { uses: [], defs: [], attributes: {}, metadata: nil, dtype: nil, axes: [] }.merge(attrs)
    )
  end

  it "raises a clear error for an opcode with no clone branch" do
    instr = fake_instr(opcode: :totally_unknown_op, result: :r1)

    expect { described_class.clone(instr, []) }
      .to raise_error(ArgumentError, /no clone branch for DF opcode :totally_unknown_op/)
  end

  it "clones a known opcode threading the new inputs and result" do
    instr = fake_instr(opcode: :map, uses: [:old_in], attributes: { fn: :add }, dtype: :float, result: :old_out)

    cloned = described_class.clone(instr, [:new_in], result: :new_out)

    expect(cloned.opcode).to eq(:map)
    expect(cloned.result).to eq(:new_out)
    expect(cloned.uses).to eq([:new_in])
  end
end
