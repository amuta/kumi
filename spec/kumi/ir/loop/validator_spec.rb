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

  # A register defined inside a loop is block-local to that loop body. Reading it
  # after loop_end compiles to a stale/undefined variable (nil in Ruby, a
  # ReferenceError / codegen crash in JS), so the validator must reject it even
  # though the register WAS defined somewhere in the function.
  it "rejects a use of a register after its defining loop has closed" do
    items = builder.load_input(result: :items, key: :items)
    elem = builder.loop_start(result: :el, source: items, axis: :items, index: :i)
    builder.load_field(result: :inside, object: elem, field: :value)
    builder.loop_end(axis: :items)
    builder.ref(result: :out, value: :inside) # :inside is out of scope here

    expect { described_class.validate!(loop_module) }
      .to raise_error(ArgumentError, /out of scope/)
  end

  it "still accepts array/accumulator registers that legitimately cross the loop boundary" do
    items = builder.load_input(result: :items, key: :items)
    arr = builder.array_init(result: :arr) # defined OUTSIDE the loop
    elem = builder.loop_start(result: :el, source: items, axis: :items, index: :i)
    value = builder.load_field(result: :value, object: elem, field: :value)
    builder.array_push(array: arr, value: value)
    builder.loop_end(axis: :items)
    builder.ref(result: :out, value: arr) # arr is still in scope (outer depth)

    expect { described_class.validate!(loop_module) }.not_to raise_error
  end

  context "when the return register is never defined" do
    let(:return_reg) { :missing }

    it "rejects the function" do
      builder.load_input(result: :out, key: :items)

      expect { described_class.validate!(loop_module) }.to raise_error(ArgumentError, /returns undefined/)
    end
  end
end
