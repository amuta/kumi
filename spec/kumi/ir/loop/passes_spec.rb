# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Kumi::IR::Loop::Passes" do
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

  before { loop_module.add_function(function) }

  def run_pass(pass)
    pass.run(graph: loop_module, context: {}).fetch_function(:compute)
  end

  def opcodes(fn)
    fn.entry_block.instructions.map(&:opcode)
  end

  # Two elementwise loops over the same source, split by an independent
  # scalar barrier, with the second loop reading the first loop's vector at
  # the current index — the shape the lowerer emits for statement groups.
  def build_two_pass_function
    xs = builder.load_input(result: :xs, key: :xs)
    scratch = builder.array_init(result: :scratch)
    el1 = builder.loop_start(result: :el1, source: xs, axis: :xs, index: :i1)
    v1 = builder.load_field(result: :v1, object: el1, field: :v)
    builder.array_push(array: scratch, value: v1)
    builder.loop_end(axis: :xs)

    k = builder.load_input(result: :k, key: :k)

    out = builder.array_init(result: :out)
    builder.loop_start(result: :el2, source: xs, axis: :xs, index: :i2)
    r = builder.index_read(result: :r, array: scratch, index: :i2)
    sum = builder.kernel_call(result: :sum, fn: :"core.add", args: [r, k])
    builder.array_push(array: out, value: sum)
    builder.loop_end(axis: :xs)
    out
  end

  describe Kumi::IR::Loop::Passes::LoopFusion do
    it "fuses same-source loops and hoists the independent barrier" do
      build_two_pass_function
      fn = run_pass(described_class.new)

      expect(opcodes(fn).count(:loop_start)).to eq(1)
      barrier_pos = opcodes(fn).index(:load_input)
      loop_pos = opcodes(fn).index(:loop_start)
      k_load = fn.entry_block.instructions.find { |i| i.opcode == :load_input && i.attributes[:key] == :k }
      expect(fn.entry_block.instructions.index(k_load)).to be < loop_pos
      expect(barrier_pos).to be < loop_pos
    end

    it "renames the second loop's element and index registers" do
      build_two_pass_function
      fn = run_pass(described_class.new)

      read = fn.entry_block.instructions.find { |i| i.opcode == :index_read }
      expect(read.inputs[1]).to eq(:i1)
      expect(fn.entry_block.instructions.none? { |i| i.uses.include?(:el2) || i.uses.include?(:i2) }).to be true
    end

    it "does not fuse loops over different sources" do
      xs = builder.load_input(result: :xs, key: :xs)
      ys = builder.load_input(result: :ys, key: :ys)
      a = builder.array_init(result: :a)
      el1 = builder.loop_start(result: :el1, source: xs, axis: :xs, index: :i1)
      builder.array_push(array: a, value: el1)
      builder.loop_end(axis: :xs)
      out = builder.array_init(result: :out)
      el2 = builder.loop_start(result: :el2, source: ys, axis: :ys, index: :i2)
      builder.array_push(array: out, value: el2)
      builder.loop_end(axis: :ys)

      fn = run_pass(described_class.new)
      expect(opcodes(fn).count(:loop_start)).to eq(2)
    end

    it "does not fuse when the barrier depends on the first loop's accumulator" do
      xs = builder.load_input(result: :xs, key: :xs)
      acc = builder.acc_init(result: :acc, fn: :"agg.sum", init: 0, nil_init: false)
      el1 = builder.loop_start(result: :el1, source: xs, axis: :xs, index: :i1)
      builder.acc_step(acc: acc, value: el1, fn: :"agg.sum", nil_init: false)
      builder.loop_end(axis: :xs)

      total = builder.acc_load(result: :total, acc: acc)

      out = builder.array_init(result: :out)
      el2 = builder.loop_start(result: :el2, source: xs, axis: :xs, index: :i2)
      scaled = builder.kernel_call(result: :scaled, fn: :"core.mul", args: [el2, total])
      builder.array_push(array: out, value: scaled)
      builder.loop_end(axis: :xs)

      fn = run_pass(described_class.new)
      expect(opcodes(fn).count(:loop_start)).to eq(2)
    end

    it "does not fuse when the second loop shift-reads the first loop's array" do
      xs = builder.load_input(result: :xs, key: :xs)
      scratch = builder.array_init(result: :scratch)
      el1 = builder.loop_start(result: :el1, source: xs, axis: :xs, index: :i1)
      builder.array_push(array: scratch, value: el1)
      builder.loop_end(axis: :xs)

      len = builder.array_len(result: :len, array: xs)

      out = builder.array_init(result: :out)
      builder.loop_start(result: :el2, source: xs, axis: :xs, index: :i2)
      function.entry_block.append(
        Kumi::IR::Loop::Ops::ShiftRead.new(result: :shifted, array: scratch, index: :i2, length: len, offset: 1, policy: :wrap)
      )
      builder.array_push(array: out, value: :shifted)
      builder.loop_end(axis: :xs)

      fn = run_pass(described_class.new)
      expect(opcodes(fn).count(:loop_start)).to eq(2)
    end
  end

  describe Kumi::IR::Loop::Passes::ArrayContraction do
    it "contracts a single-pass intermediate array into its scalar" do
      xs = builder.load_input(result: :xs, key: :xs)
      scratch = builder.array_init(result: :scratch)
      out = builder.array_init(result: :out)
      el = builder.loop_start(result: :el, source: xs, axis: :xs, index: :i)
      v = builder.load_field(result: :v, object: el, field: :v)
      builder.array_push(array: scratch, value: v)
      r = builder.index_read(result: :r, array: scratch, index: :i)
      doubled = builder.kernel_call(result: :doubled, fn: :"core.add", args: [r, r])
      builder.array_push(array: out, value: doubled)
      builder.loop_end(axis: :xs)

      fn = run_pass(described_class.new)

      expect(opcodes(fn)).not_to include(:index_read)
      expect(opcodes(fn).count(:array_init)).to eq(1)
      expect(opcodes(fn).count(:array_push)).to eq(1)
      add = fn.entry_block.instructions.find { |i| i.opcode == :kernel_call }
      expect(add.inputs).to eq(%i[v v])
    end

    it "keeps arrays that are shift-read" do
      xs = builder.load_input(result: :xs, key: :xs)
      len = builder.array_len(result: :len, array: xs)
      scratch = builder.array_init(result: :scratch)
      out = builder.array_init(result: :out)
      builder.loop_start(result: :el, source: xs, axis: :xs, index: :i)
      builder.array_push(array: scratch, value: :el)
      function.entry_block.append(
        Kumi::IR::Loop::Ops::ShiftRead.new(result: :shifted, array: scratch, index: :i, length: len, offset: -1, policy: :clamp)
      )
      builder.array_push(array: out, value: :shifted)
      builder.loop_end(axis: :xs)

      fn = run_pass(described_class.new)
      expect(opcodes(fn).count(:array_init)).to eq(2)
      expect(opcodes(fn)).to include(:shift_read)
    end

    it "keeps the function's returned array" do
      xs = builder.load_input(result: :xs, key: :xs)
      out = builder.array_init(result: :out)
      builder.loop_start(result: :el, source: xs, axis: :xs, index: :i)
      builder.array_push(array: out, value: :el)
      builder.loop_end(axis: :xs)

      fn = run_pass(described_class.new)
      expect(opcodes(fn)).to include(:array_init, :array_push)
    end

    it "keeps arrays read in a different loop" do
      build_two_pass_function
      fn = run_pass(described_class.new)

      expect(opcodes(fn)).to include(:index_read)
      expect(opcodes(fn).count(:array_init)).to eq(2)
    end
  end

  describe Kumi::IR::Loop::Pipeline do
    it "fuses then contracts, producing a single-loop scratch-free function" do
      build_two_pass_function
      optimized = described_class.run(graph: loop_module, context: {})
      fn = optimized.fetch_function(:compute)

      expect(opcodes(fn).count(:loop_start)).to eq(1)
      expect(opcodes(fn).count(:array_init)).to eq(1)
      expect(opcodes(fn)).not_to include(:index_read)
      expect { Kumi::IR::Loop::Validator.validate!(optimized) }.not_to raise_error
    end
  end
end
