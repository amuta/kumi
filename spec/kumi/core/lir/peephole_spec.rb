# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::LIR::Peephole do
  let(:build) { Kumi::Core::LIR::Build }
  let(:ids) { Kumi::Core::LIR::Ids.new }

  describe ".run" do
    it "replaces a matching instruction window" do
      ops = []
      ops << build.constant(value: 1, dtype: :integer, as: :t1, ids: ids)
      ops << build.constant(value: 2, dtype: :integer, as: :t2, ids: ids)
      ops << build.kernel_call(function: "core.add", args: %i[t1 t2], out_dtype: :integer, as: :t3, ids: ids)
      ops << build.yield(result_register: :t3)

      described_class.run(ops) do |window|
        next unless window.match?(:Constant, :Constant, :KernelCall)

        kernel = window.instruction(2)
        replacement = build.constant(
          value: 3,
          dtype: kernel.stamp.dtype,
          as: kernel.result_register,
          ids: ids
        )

        window.replace(3, with: replacement)
        window.skip
      end

      expect(ops.map(&:opcode)).to eq(%i[Constant Yield])
      value = ops.first.immediates.first
      expect(value.value).to eq(3)
      expect(ops.first.result_register).to eq(:t3)
      expect(ops.last.inputs).to eq([:t3])
    end

    it "re-evaluates a position after deleting the current instruction" do
      ops = []
      ops << build.constant(value: 0, dtype: :integer, as: :z, ids: ids)
      ops << build.constant(value: 42, dtype: :integer, as: :answer, ids: ids)

      described_class.run(ops) { |window| window.zero? ? window.delete : window.skip }

      expect(ops.length).to eq(1)
      expect(ops.first.opcode).to eq(:Constant)
      expect(ops.first.immediates.first.value).to eq(42)
    end

    it "exposes helpers for constant detection and literal access" do
      ops = []
      ops << build.constant(value: 0, dtype: :integer, ids: ids)
      ops << build.constant(value: 7, dtype: :integer, ids: ids)

      seen = []

      described_class.run(ops) do |window|
        seen << [window.const?, window.zero?, window.literal_value]
        window.skip
      end

      expect(seen).to eq([[true, true, 0], [true, false, 7]])
    end
  end
end
