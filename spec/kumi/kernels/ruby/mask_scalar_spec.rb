# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Kernels::Ruby::MaskScalar do
  describe ".where" do
    it "returns if_true when condition is true" do
      expect(described_class.where(true, "yes", "no")).to eq("yes")
    end

    it "returns if_false when condition is false" do
      expect(described_class.where(false, "yes", "no")).to eq("no")
    end

    it "handles truthy conditions" do
      expect(described_class.where(1, "yes", "no")).to eq("yes")
      expect(described_class.where("hello", "yes", "no")).to eq("yes")
      expect(described_class.where([1, 2, 3], "yes", "no")).to eq("yes")
      expect(described_class.where({}, "yes", "no")).to eq("yes")
    end

    it "handles falsy conditions" do
      expect(described_class.where(nil, "yes", "no")).to eq("no")
      expect(described_class.where(false, "yes", "no")).to eq("no")
    end

    it "handles zero as truthy" do
      expect(described_class.where(0, "yes", "no")).to eq("yes")
    end

    it "handles empty string as truthy" do
      expect(described_class.where("", "yes", "no")).to eq("yes")
    end

    it "handles different return types" do
      expect(described_class.where(true, 42, "no")).to eq(42)
      expect(described_class.where(false, 42, "no")).to eq("no")
      
      expect(described_class.where(true, 3.14, 2.71)).to eq(3.14)
      expect(described_class.where(false, 3.14, 2.71)).to eq(2.71)
    end

    it "handles nil return values" do
      expect(described_class.where(true, nil, "no")).to be_nil
      expect(described_class.where(false, "yes", nil)).to be_nil
      expect(described_class.where(true, nil, nil)).to be_nil
      expect(described_class.where(false, nil, nil)).to be_nil
    end

    it "handles arrays as return values" do
      arr1 = [1, 2, 3]
      arr2 = [4, 5, 6]
      expect(described_class.where(true, arr1, arr2)).to eq(arr1)
      expect(described_class.where(false, arr1, arr2)).to eq(arr2)
    end

    it "handles hashes as return values" do
      hash1 = { a: 1, b: 2 }
      hash2 = { c: 3, d: 4 }
      expect(described_class.where(true, hash1, hash2)).to eq(hash1)
      expect(described_class.where(false, hash1, hash2)).to eq(hash2)
    end

    it "handles complex conditions" do
      # Complex boolean expressions would be evaluated before reaching this kernel
      expect(described_class.where(5 > 3, "greater", "not greater")).to eq("greater")
      expect(described_class.where(2 > 5, "greater", "not greater")).to eq("not greater")
    end

    it "preserves object identity" do
      obj1 = Object.new
      obj2 = Object.new
      
      result_true = described_class.where(true, obj1, obj2)
      result_false = described_class.where(false, obj1, obj2)
      
      expect(result_true).to be(obj1)
      expect(result_false).to be(obj2)
    end

    it "handles nested where operations" do
      # Simulating: where(a, where(b, x, y), z)
      inner_result = described_class.where(true, "x", "y")  # returns "x"
      outer_result = described_class.where(false, inner_result, "z")  # returns "z"
      expect(outer_result).to eq("z")
      
      inner_result = described_class.where(false, "x", "y")  # returns "y"  
      outer_result = described_class.where(true, inner_result, "z")  # returns "y"
      expect(outer_result).to eq("y")
    end
  end
end