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
      expect(described_class.size(%w[hello world])).to eq(2)
    end

    it "returns size of mixed type array" do
      expect(described_class.size([1, "hello", true, 3.14])).to eq(4)
    end

    it "handles nil input" do
      expect(described_class.size(nil)).to be_nil
    end

    it "works with any enumerable" do
      expect(described_class.size(1..10)).to eq(10)
    end

    it "handles nested arrays" do
      nested = [[1, 2], [3, 4, 5], [6]]
      expect(described_class.size(nested)).to eq(3)
    end
  end

  describe "#array_get" do
    it "returns element at index" do
      expect(described_class.array_get(%i[a b c], 1)).to eq(:b)
      expect(described_class.array_get(%i[a b c], 0)).to eq(:a)
    end

    it "raises IndexError for out of bounds" do
      expect { described_class.array_get(%i[a b], 5) }.to raise_error(IndexError)
      expect { described_class.array_get(%i[a b], -3) }.to raise_error(IndexError)
    end

    it "raises IndexError for nil array" do
      expect { described_class.array_get(nil, 0) }.to raise_error(IndexError, "array is nil")
    end
  end

  describe "#struct_get" do
    it "returns value for hash key" do
      expect(described_class.struct_get({ a: 1, b: 2 }, :a)).to eq(1)
      expect(described_class.struct_get({ a: 1, b: 2 }, "a")).to eq(1)
    end

    it "handles string keys in hash" do
      expect(described_class.struct_get({ "name" => "Alice" }, :name)).to eq("Alice")
      expect(described_class.struct_get({ "name" => "Alice" }, "name")).to eq("Alice")
    end

    it "raises KeyError for missing key" do
      expect { described_class.struct_get({ a: 1 }, :missing) }.to raise_error(KeyError, "missing key :missing")
    end

    it "raises KeyError for nil struct" do
      expect { described_class.struct_get(nil, :key) }.to raise_error(KeyError, "struct is nil")
    end
  end

  describe "#array_contains" do
    it "returns true when value is present" do
      expect(described_class.array_contains([1, 2, 3], 2)).to eq(true)
      expect(described_class.array_contains([1, nil, 3], nil)).to eq(true)
    end

    it "returns false when value is not present" do
      expect(described_class.array_contains([1, 2, 3], 5)).to eq(false)
    end

    it "returns nil when array is nil" do
      expect(described_class.array_contains(nil, 2)).to be_nil
    end
  end

  describe "IR/VM operations (stubs)" do
    describe ".join_zip" do
      it "raises NotImplementedError indicating should be in IR/VM" do
        expect do
          described_class.join_zip([1, 2], [3, 4])
        end.to raise_error(NotImplementedError, "join operations should be implemented in IR/VM")
      end
    end

    describe ".join_product" do
      it "raises NotImplementedError indicating should be in IR/VM" do
        expect do
          described_class.join_product([1, 2], [3, 4])
        end.to raise_error(NotImplementedError, "join operations should be implemented in IR/VM")
      end
    end

    describe ".align_to" do
      it "raises NotImplementedError indicating should be in IR/VM" do
        expect do
          described_class.align_to([1, 2, 3], %i[i j])
        end.to raise_error(NotImplementedError, "align_to should be implemented in IR/VM")
      end
    end

    describe ".lift" do
      it "raises NotImplementedError indicating should be in IR/VM" do
        expect do
          described_class.lift([1, 2, 3], [0, 0, 1])
        end.to raise_error(NotImplementedError, "lift should be implemented in IR/VM")
      end
    end

    describe ".flatten" do
      it "flattens exactly one level" do
        expect(described_class.flatten([[1, 2], [3]])).to eq([1, 2, 3])
        expect(described_class.flatten([%i[a b], %i[c d]])).to eq(%i[a b c d])
      end

      it "handles nested arrays correctly" do
        expect(described_class.flatten([[[1, 2]], [[3, 4]]])).to eq([[1, 2], [3, 4]])
      end

      it "returns nil for nil input" do
        expect(described_class.flatten(nil)).to be_nil
      end
    end
  end
end
