# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Kernels::Ruby::AggregateCore do
  describe ".kumi_sum" do
    it "sums integers" do
      expect(described_class.kumi_sum([1, 2, 3, 4, 5])).to eq(15)
    end

    it "sums floats" do
      expect(described_class.kumi_sum([1.5, 2.5, 3.0])).to eq(7.0)
    end

    it "sums mixed numbers" do
      expect(described_class.kumi_sum([1, 2.5, 3])).to eq(6.5)
    end

    it "handles empty array" do
      expect(described_class.kumi_sum([])).to eq(0)
    end

    it "handles single element" do
      expect(described_class.kumi_sum([42])).to eq(42)
    end

    it "handles negative numbers" do
      expect(described_class.kumi_sum([-1, 2, -3, 4])).to eq(2)
    end

    it "handles zeros" do
      expect(described_class.kumi_sum([0, 0, 0])).to eq(0)
    end

    context "with nulls" do
      it "skips nulls by default" do
        expect(described_class.kumi_sum([1, nil, 3, nil, 5])).to eq(9)
      end

      it "skips nulls when skip_nulls is true" do
        expect(described_class.kumi_sum([1, nil, 3], skip_nulls: true)).to eq(4)
      end

      it "includes nulls when skip_nulls is false" do
        expect {
          described_class.kumi_sum([1, nil, 3], skip_nulls: false)
        }.to raise_error(TypeError)
      end

      it "returns nil when all values are null and skip_nulls is true" do
        expect(described_class.kumi_sum([nil, nil, nil])).to eq(0)
      end
    end

    context "with min_count" do
      it "returns nil when count is below min_count" do
        expect(described_class.kumi_sum([1, 2], min_count: 3)).to be_nil
      end

      it "returns sum when count meets min_count" do
        expect(described_class.kumi_sum([1, 2, 3], min_count: 3)).to eq(6)
      end

      it "considers skip_nulls with min_count" do
        expect(described_class.kumi_sum([1, nil, 3], min_count: 3)).to be_nil
        expect(described_class.kumi_sum([1, nil, 3], min_count: 2)).to eq(4)
      end
    end
  end

  describe ".kumi_min" do
    it "finds minimum of integers" do
      expect(described_class.kumi_min([5, 2, 8, 1, 9])).to eq(1)
    end

    it "finds minimum of floats" do
      expect(described_class.kumi_min([5.5, 2.1, 8.9, 1.2])).to eq(1.2)
    end

    it "finds minimum of mixed numbers" do
      expect(described_class.kumi_min([5, 2.1, 8, 1.2])).to eq(1.2)
    end

    it "handles single element" do
      expect(described_class.kumi_min([42])).to eq(42)
    end

    it "handles negative numbers" do
      expect(described_class.kumi_min([-5, -2, -8, -1])).to eq(-8)
    end

    it "handles empty array" do
      expect(described_class.kumi_min([])).to be_nil
    end

    context "with nulls" do
      it "skips nulls by default" do
        expect(described_class.kumi_min([5, nil, 2, nil, 8])).to eq(2)
      end

      it "returns nil when all values are null" do
        expect(described_class.kumi_min([nil, nil, nil])).to be_nil
      end
    end

    context "with min_count" do
      it "returns nil when count is below min_count" do
        expect(described_class.kumi_min([1, 2], min_count: 3)).to be_nil
      end

      it "returns min when count meets min_count" do
        expect(described_class.kumi_min([3, 1, 2], min_count: 3)).to eq(1)
      end
    end
  end

  describe ".kumi_max" do
    it "finds maximum of integers" do
      expect(described_class.kumi_max([5, 2, 8, 1, 9])).to eq(9)
    end

    it "finds maximum of floats" do
      expect(described_class.kumi_max([5.5, 2.1, 8.9, 1.2])).to eq(8.9)
    end

    it "finds maximum of mixed numbers" do
      expect(described_class.kumi_max([5, 2.1, 8.9, 1])).to eq(8.9)
    end

    it "handles single element" do
      expect(described_class.kumi_max([42])).to eq(42)
    end

    it "handles negative numbers" do
      expect(described_class.kumi_max([-5, -2, -8, -1])).to eq(-1)
    end

    it "handles empty array" do
      expect(described_class.kumi_max([])).to be_nil
    end

    context "with nulls" do
      it "skips nulls by default" do
        expect(described_class.kumi_max([5, nil, 9, nil, 2])).to eq(9)
      end

      it "returns nil when all values are null" do
        expect(described_class.kumi_max([nil, nil, nil])).to be_nil
      end
    end
  end

  describe ".kumi_mean" do
    it "calculates mean of integers" do
      expect(described_class.kumi_mean([1, 2, 3, 4, 5])).to eq(3.0)
    end

    it "calculates mean of floats" do
      expect(described_class.kumi_mean([2.0, 4.0, 6.0])).to eq(4.0)
    end

    it "handles single element" do
      expect(described_class.kumi_mean([42])).to eq(42.0)
    end

    it "handles empty array" do
      expect(described_class.kumi_mean([])).to be_nil
    end

    it "returns float result" do
      result = described_class.kumi_mean([1, 2])
      expect(result).to eq(1.5)
      expect(result).to be_a(Float)
    end

    context "with nulls" do
      it "skips nulls by default" do
        expect(described_class.kumi_mean([2, nil, 4, nil, 6])).to eq(4.0)
      end

      it "returns nil when all values are null" do
        expect(described_class.kumi_mean([nil, nil, nil])).to be_nil
      end
    end

    context "with min_count" do
      it "returns nil when count is below min_count" do
        expect(described_class.kumi_mean([1, 2], min_count: 3)).to be_nil
      end

      it "returns mean when count meets min_count" do
        expect(described_class.kumi_mean([1, 2, 3], min_count: 3)).to eq(2.0)
      end
    end
  end

  describe ".kumi_any" do
    it "returns true when any value is truthy" do
      expect(described_class.kumi_any([false, false, true, false])).to be true
    end

    it "returns false when all values are falsy" do
      expect(described_class.kumi_any([false, false, false])).to be false
    end

    it "handles empty array" do
      expect(described_class.kumi_any([])).to be false
    end

    it "handles truthy non-boolean values" do
      expect(described_class.kumi_any([false, 0, "", false])).to be true
      expect(described_class.kumi_any([false, false, "hello"])).to be true
    end

    it "handles falsy non-boolean values" do
      expect(described_class.kumi_any([false, nil, false])).to be false
    end

    context "with nulls" do
      it "skips nulls by default" do
        expect(described_class.kumi_any([false, nil, true, nil])).to be true
        expect(described_class.kumi_any([false, nil, false, nil])).to be false
      end

      it "returns nil when all values are null" do
        expect(described_class.kumi_any([nil, nil, nil])).to be false
      end
    end
  end

  describe ".kumi_all" do
    it "returns true when all values are truthy" do
      expect(described_class.kumi_all([true, true, true])).to be true
    end

    it "returns false when any value is falsy" do
      expect(described_class.kumi_all([true, false, true])).to be false
    end

    it "handles empty array" do
      expect(described_class.kumi_all([])).to be true
    end

    it "handles truthy non-boolean values" do
      expect(described_class.kumi_all([1, "hello", true])).to be true
      expect(described_class.kumi_all([1, "", true])).to be true
    end

    it "handles falsy non-boolean values" do
      expect(described_class.kumi_all([1, false, true])).to be false
    end

    context "with nulls" do
      it "skips nulls by default" do
        expect(described_class.kumi_all([true, nil, true, nil])).to be true
        expect(described_class.kumi_all([true, nil, false, nil])).to be false
      end

      it "returns true when all non-null values are truthy" do
        expect(described_class.kumi_all([nil, nil, nil])).to be true
      end
    end
  end

  describe ".kumi_count" do
    it "counts all elements" do
      expect(described_class.kumi_count([1, 2, 3, 4, 5])).to eq(5)
    end

    it "handles empty array" do
      expect(described_class.kumi_count([])).to eq(0)
    end

    it "counts different types" do
      expect(described_class.kumi_count([1, "hello", true, 3.14])).to eq(4)
    end

    context "with nulls" do
      it "skips nulls by default" do
        expect(described_class.kumi_count([1, nil, 3, nil, 5])).to eq(3)
      end

      it "counts all when skip_nulls is false" do
        expect(described_class.kumi_count([1, nil, 3], skip_nulls: false)).to eq(3)
      end

      it "returns 0 when all values are null and skip_nulls is true" do
        expect(described_class.kumi_count([nil, nil, nil])).to eq(0)
      end
    end

    context "with min_count" do
      it "returns nil when count is below min_count" do
        expect(described_class.kumi_count([1, 2], min_count: 3)).to be_nil
      end

      it "returns count when count meets min_count" do
        expect(described_class.kumi_count([1, 2, 3], min_count: 3)).to eq(3)
      end
    end
  end
end