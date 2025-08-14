# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Kernels::Ruby::VectorStruct do
  describe ".size" do
    it "returns size of array" do
      expect(described_class.size([1, 2, 3, 4, 5])).to eq(5)
    end

    it "returns size of empty array" do
      expect(described_class.size([])).to eq(0)
    end

    it "returns size of string array" do
      expect(described_class.size(["hello", "world"])).to eq(2)
    end

    it "returns size of mixed type array" do
      expect(described_class.size([1, "hello", true, 3.14])).to eq(4)
    end

    it "handles nil input" do
      expect(described_class.size(nil)).to be_nil
    end

    it "works with any enumerable" do
      expect(described_class.size((1..10))).to eq(10)
    end

    it "handles nested arrays" do
      nested = [[1, 2], [3, 4, 5], [6]]
      expect(described_class.size(nested)).to eq(3)
    end
  end

  describe "IR/VM operations (stubs)" do
    describe ".join_zip" do
      it "raises NotImplementedError indicating should be in IR/VM" do
        expect {
          described_class.join_zip([1, 2], [3, 4])
        }.to raise_error(NotImplementedError, "join operations should be implemented in IR/VM")
      end
    end

    describe ".join_product" do
      it "raises NotImplementedError indicating should be in IR/VM" do
        expect {
          described_class.join_product([1, 2], [3, 4])
        }.to raise_error(NotImplementedError, "join operations should be implemented in IR/VM")
      end
    end

    describe ".align_to" do
      it "raises NotImplementedError indicating should be in IR/VM" do
        expect {
          described_class.align_to([1, 2, 3], [:i, :j])
        }.to raise_error(NotImplementedError, "align_to should be implemented in IR/VM")
      end
    end

    describe ".lift" do
      it "raises NotImplementedError indicating should be in IR/VM" do
        expect {
          described_class.lift([1, 2, 3], [0, 0, 1])
        }.to raise_error(NotImplementedError, "lift should be implemented in IR/VM")
      end
    end

    describe ".flatten" do
      it "raises NotImplementedError indicating should be in IR/VM" do
        expect {
          described_class.flatten([[1, 2], [3, 4]])
        }.to raise_error(NotImplementedError, "flatten should be implemented in IR/VM")
      end

      it "handles variable arguments due to Ruby flatten conflict" do
        expect {
          described_class.flatten("any", "args", "work")
        }.to raise_error(NotImplementedError, "flatten should be implemented in IR/VM")
      end
    end

    describe ".take" do
      it "raises NotImplementedError indicating should be in IR/VM" do
        expect {
          described_class.take([1, 2, 3], [0, 2])
        }.to raise_error(NotImplementedError, "take should be implemented in IR/VM")
      end
    end
  end
end