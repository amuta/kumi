# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::Loop::Validator do
  let(:loop_module) { Kumi::IR::Loop::Module.new(name: :demo) }
  let(:function) do
    Kumi::IR::Loop::Function.new(
      name: :compute,
      return_reg: return_reg,
      blocks: [Kumi::IR::Base::Block.new(name: :entry)]
    )
  end
  let(:return_reg) { :out }
  let(:builder) { Kumi::IR::Loop::Builder.new(ir_module: loop_module, function:) }

  before do
    loop_module.add_function(function)
  end

  it "accepts a valid loop nest with a reduction" do
    items = builder.load_input(result: :items, key: :items)
    acc = builder.acc_init(result: :acc, fn: :"agg.sum", init: 0, nil_init: false)
    elem = builder.loop_start(result: :el, source: items, axis: :items, index: :i)
    value = builder.load_field(result: :value, object: elem, field: :value)
    builder.acc_step(acc: acc, value: value, fn: :"agg.sum", nil_init: false)
    builder.loop_end(axis: :items)
    builder.acc_load(result: :out, acc: acc)

    expect { described_class.validate!(loop_module) }.not_to raise_error
  end

  it "rejects vector-semantics opcodes" do
    builder.load_input(result: :out, key: :xs)
    function.entry_block.append(
      Kumi::IR::Vec::Ops::Reduce.new(result: :total, fn: :"agg.sum", arg: :out, over_axes: [:xs], axes: [], dtype: :integer)
    )

    expect { described_class.validate!(loop_module) }.to raise_error(ArgumentError, /does not support opcode/)
  end

  it "rejects unclosed loops" do
    items = builder.load_input(result: :items, key: :items)
    builder.loop_start(result: :out, source: items, axis: :items, index: :i)

    expect { described_class.validate!(loop_module) }.to raise_error(ArgumentError, /unclosed loops/)
  end

  it "rejects uses of undefined registers" do
    builder.kernel_call(result: :out, fn: :"core.add", args: %i[ghost ghost])

    expect { described_class.validate!(loop_module) }.to raise_error(ArgumentError, /undefined register/)
  end

  context "when the return register is never defined" do
    let(:return_reg) { :missing }

    it "rejects the function" do
      builder.load_input(result: :out, key: :items)

      expect { described_class.validate!(loop_module) }.to raise_error(ArgumentError, /returns undefined/)
    end
  end
end
