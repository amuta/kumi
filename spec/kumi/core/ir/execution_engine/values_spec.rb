# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::IR::ExecutionEngine::Values do
  describe ".scalar" do
    it "wraps any value (including nil)" do
      expect(described_class.scalar(42)).to eq(k: :scalar, v: 42)
      expect(described_class.scalar(nil)).to eq(k: :scalar, v: nil)
    end
  end

  describe ".vec" do
    it "creates a vec without indices" do
      rows = [{ v: 1 }, { v: 2 }]
      expect(described_class.vec([:i], rows, false)).to eq(k: :vec, scope: [:i], rows: rows, has_idx: false, rank: 0)
    end

    it "creates a vec with indices (multi-dim ok) and supports empty" do
      rows = [{ v: 10, idx: [0, 1] }, { v: 20, idx: [1, 0] }]
      expect(described_class.vec(%i[i j], rows, true)).to eq(k: :vec, scope: %i[i j], rows: rows, has_idx: true, rank: 2)
      expect(described_class.vec([:i], [], true)).to eq(k: :vec, scope: [:i], rows: [], has_idx: true, rank: 0)
    end
  end

  describe ".row" do
    it "builds rows with/without index; normalizes idx to array" do
      expect(described_class.row(7)).to eq(v: 7)
      expect(described_class.row(7, 3)).to eq(v: 7, idx: [3])
      expect(described_class.row(7, [1, 2])).to eq(v: 7, idx: [1, 2])
    end
  end

  describe "predicates" do
    it "detects scalar vs vec" do
      expect(described_class.scalar?(k: :scalar, v: 1)).to be true
      expect(described_class.scalar?(k: :vec, scope: [], rows: [], has_idx: false)).to be false
      expect(described_class.vec?(k: :vec, scope: [:i], rows: [], has_idx: true)).to be true
      expect(described_class.vec?(k: :scalar, v: 1)).to be false
    end
  end
end
