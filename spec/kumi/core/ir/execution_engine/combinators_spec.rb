# frozen_string_literal: true

require "spec_helper"
require "benchmark/ips"

RSpec.describe Kumi::Core::IR::ExecutionEngine::Combinators do
  let(:scalar) { ->(v) { { k: :scalar, v: v } } }
  let(:vec) { ->(scope, rows, has_idx) { { k: :vec, scope: scope, rows: rows, has_idx: has_idx } } }
  let(:row) { ->(v, idx = nil) { idx ? { v: v, idx: Array(idx) } : { v: v } } }

  describe ".broadcast_scalar" do
    it "broadcasts scalar over vec and preserves indices" do
      v = vec.call([:i], [row.call(1, [0]), row.call(2, [1])], true)
      s = scalar.call(9)

      result = described_class.broadcast_scalar(s, v)

      expect(result[:k]).to eq(:vec)
      expect(result[:scope]).to eq([:i])
      expect(result[:has_idx]).to be true
      expect(result[:rows]).to eq([
                                    { v: 9, idx: [0] },
                                    { v: 9, idx: [1] }
                                  ])
    end

    it "broadcasts scalar over vec without indices" do
      v = vec.call([:i], [row.call(1), row.call(2)], false)
      s = scalar.call(10)

      result = described_class.broadcast_scalar(s, v)

      expect(result[:rows]).to eq([
                                    { v: 10 },
                                    { v: 10 }
                                  ])
    end

    it "rejects vec as first argument" do
      v = vec.call([:i], [row.call(1, [0])], true)

      expect do
        described_class.broadcast_scalar(v, v)
      end.to raise_error(/First arg must be scalar/)
    end

    it "rejects scalar as second argument" do
      s = scalar.call(5)

      expect do
        described_class.broadcast_scalar(s, s)
      end.to raise_error(/Second arg must be vec/)
    end

    it "handles empty vectors" do
      v = vec.call([:i], [], true)
      s = scalar.call(42)

      result = described_class.broadcast_scalar(s, v)

      expect(result[:rows]).to be_empty
    end
  end

  describe ".zip_same_scope" do
    it "zips vectors with same scope and length" do
      v1 = vec.call([:i], [row.call(1, [0]), row.call(2, [1])], true)
      v2 = vec.call([:i], [row.call(10, [0]), row.call(20, [1])], true)

      result = described_class.zip_same_scope(v1, v2)

      expect(result[:k]).to eq(:vec)
      expect(result[:scope]).to eq([:i])
      expect(result[:has_idx]).to be true
      expect(result[:rows]).to eq([
                                    { v: [1, 10], idx: [0] },
                                    { v: [2, 20], idx: [1] }
                                  ])
    end

    it "zips multiple vectors" do
      v1 = vec.call([:i], [row.call(1, [0])], true)
      v2 = vec.call([:i], [row.call(2, [0])], true)
      v3 = vec.call([:i], [row.call(3, [0])], true)

      result = described_class.zip_same_scope(v1, v2, v3)

      expect(result[:rows]).to eq([
                                    { v: [1, 2, 3], idx: [0] }
                                  ])
    end

    it "preserves indices from first vector" do
      v1 = vec.call(%i[i j], [row.call(1, [0, 1]), row.call(2, [0, 2])], true)
      v2 = vec.call(%i[i j], [row.call(10, [0, 1]), row.call(20, [0, 2])], true)

      result = described_class.zip_same_scope(v1, v2)

      expect(result[:rows][0][:idx]).to eq([0, 1])
      expect(result[:rows][1][:idx]).to eq([0, 2])
    end

    it "rejects scalars" do
      v = vec.call([:i], [row.call(1)], false)
      s = scalar.call(5)

      expect do
        described_class.zip_same_scope(v, s)
      end.to raise_error(/All arguments must be vecs/)
    end

    it "rejects different scopes" do
      v1 = vec.call([:i], [row.call(1)], false)
      v2 = vec.call([:j], [row.call(2)], false)

      expect do
        described_class.zip_same_scope(v1, v2)
      end.to raise_error(/All vecs must have same scope/)
    end

    it "rejects different row counts" do
      v1 = vec.call([:i], [row.call(1), row.call(2)], false)
      v2 = vec.call([:i], [row.call(10)], false)

      expect do
        described_class.zip_same_scope(v1, v2)
      end.to raise_error(/All vecs must have same row count/)
    end
  end

  describe ".align_to" do
    it "aligns lower-rank to higher-rank vec" do
      tgt = vec.call(%i[i j], [
                       row.call(:a, [0, 0]),
                       row.call(:b, [0, 1]),
                       row.call(:c, [1, 0])
                     ], true)

      src = vec.call([:i], [
                       row.call(10, [0]),
                       row.call(20, [1])
                     ], true)

      result = described_class.align_to(tgt, src, to_scope: %i[i j], require_unique: true, on_missing: :error)

      expect(result[:k]).to eq(:vec)
      expect(result[:scope]).to eq(%i[i j])
      expect(result[:rows]).to eq([
                                    { v: 10, idx: [0, 0] },
                                    { v: 10, idx: [0, 1] },
                                    { v: 20, idx: [1, 0] }
                                  ])
    end

    it "handles missing prefixes with nil policy" do
      tgt = vec.call(%i[i j], [
                       row.call(nil, [0, 0]),
                       row.call(nil, [0, 1]),
                       row.call(nil, [1, 0])
                     ], true)

      src = vec.call([:i], [
                       row.call(10, [0])
                     ], true)

      result = described_class.align_to(tgt, src, to_scope: %i[i j], on_missing: :nil)

      expect(result[:rows]).to eq([
                                    { v: 10, idx: [0, 0] },
                                    { v: 10, idx: [0, 1] },
                                    { v: nil, idx: [1, 0] }
                                  ])
    end

    it "raises on missing prefixes with error policy" do
      tgt = vec.call(%i[i j], [row.call(nil, [1, 0])], true)
      src = vec.call([:i], [row.call(10, [0])], true)

      expect do
        described_class.align_to(tgt, src, to_scope: %i[i j], on_missing: :error)
      end.to raise_error(/missing prefix \[1\]/)
    end

    it "enforces unique prefixes when required" do
      tgt = vec.call([:i], [row.call(nil, [0])], true)
      src = vec.call([:i], [
                       row.call(10, [0]),
                       row.call(20, [0])
                     ], true)

      expect do
        described_class.align_to(tgt, src, to_scope: [:i], require_unique: true, on_missing: :error)
      end.to raise_error(/non-unique prefix/)
    end

    it "rejects non-vecs" do
      s = scalar.call(5)
      v = vec.call([:i], [row.call(1, [0])], true)

      expect do
        described_class.align_to(s, v, to_scope: [:i])
      end.to raise_error(/align_to expects vecs with indices/)
    end

    it "rejects vecs without indices" do
      tgt = vec.call([:i], [row.call(1)], false)
      src = vec.call([:i], [row.call(10)], false)

      expect do
        described_class.align_to(tgt, src, to_scope: [:i])
      end.to raise_error(/align_to expects vecs with indices/)
    end

    it "rejects incompatible scopes" do
      tgt = vec.call([:i], [row.call(1, [0])], true)
      src = vec.call(%i[i j], [row.call(10, [0, 0])], true)

      expect do
        described_class.align_to(tgt, src, to_scope: [:i])
      end.to raise_error(/scope not prefix-compatible/)
    end
  end

  describe ".join_zip" do
    it "joins two equal-length vectors from different scopes" do
      v1 = vec.call([:i], [row.call(1, [0]), row.call(2, [1])], true)
      v2 = vec.call([:j], [row.call(10, [0]), row.call(20, [1])], true)

      result = described_class.join_zip([v1, v2])

      expect(result[:k]).to eq(:vec)
      expect(result[:scope]).to eq([:i, :j])
      expect(result[:has_idx]).to be true
      expect(result[:rows]).to eq([
                                    { v: [1, 10], idx: [0] },
                                    { v: [2, 20], idx: [1] }
                                  ])
    end

    it "joins multiple vectors" do
      v1 = vec.call([:i], [row.call(1, [0])], true)
      v2 = vec.call([:j], [row.call(2, [0])], true)
      v3 = vec.call([:k], [row.call(3, [0])], true)

      result = described_class.join_zip([v1, v2, v3])

      expect(result[:scope]).to eq([:i, :j, :k])
      expect(result[:rows]).to eq([
                                    { v: [1, 2, 3], idx: [0] }
                                  ])
    end

    it "returns single vector when given one argument" do
      v = vec.call([:i], [row.call(42, [0])], true)

      result = described_class.join_zip([v])

      expect(result).to eq(v)
    end

    it "handles vectors without indices" do
      v1 = vec.call([:i], [row.call(1), row.call(2)], false)
      v2 = vec.call([:j], [row.call(10), row.call(20)], false)

      result = described_class.join_zip([v1, v2])

      expect(result[:has_idx]).to be false
      expect(result[:rows]).to eq([
                                    { v: [1, 10] },
                                    { v: [2, 20] }
                                  ])
    end

    it "raises on length mismatch with error policy" do
      v1 = vec.call([:i], [row.call(1), row.call(2)], false)
      v2 = vec.call([:j], [row.call(10)], false)

      expect do
        described_class.join_zip([v1, v2], on_missing: :error)
      end.to raise_error(/Length mismatch in join_zip: \[2, 1\]/)
    end

    it "pads with nil on length mismatch with nil policy" do
      v1 = vec.call([:i], [row.call(1), row.call(2)], false)
      v2 = vec.call([:j], [row.call(10)], false)

      result = described_class.join_zip([v1, v2], on_missing: :nil)

      expect(result[:rows]).to eq([
                                    { v: [1, 10] },
                                    { v: [2, nil] }
                                  ])
    end

    it "raises on unknown on_missing policy" do
      v1 = vec.call([:i], [row.call(1)], false)
      v2 = vec.call([:j], [row.call(10)], false)

      expect do
        described_class.join_zip([v1, v2], on_missing: :unknown)
      end.to raise_error(/unknown on_missing policy: unknown/)
    end

    it "rejects non-vector arguments" do
      v = vec.call([:i], [row.call(1)], false)
      s = scalar.call(5)

      expect do
        described_class.join_zip([v, s])
      end.to raise_error(/All arguments must be vecs/)
    end

    it "concatenates output scope from all input scopes" do
      v1 = vec.call([:x, :y], [row.call(1, [0, 0])], true)
      v2 = vec.call([:z], [row.call(2, [0])], true)

      result = described_class.join_zip([v1, v2])

      expect(result[:scope]).to eq([:x, :y, :z])
    end

    it "preserves has_idx if any input has indices" do
      v1 = vec.call([:i], [row.call(1)], false)
      v2 = vec.call([:j], [row.call(2, [0])], true)

      result = described_class.join_zip([v1, v2])

      expect(result[:has_idx]).to be true
    end
  end

  describe ".group_rows" do
    it "returns values at depth 0" do
      rows = [
        row.call(1, [0, 0]),
        row.call(2, [0, 1]),
        row.call(3, [1, 0])
      ]

      result = described_class.group_rows(rows, 0)

      expect(result).to eq([1, 2, 3])
    end

    it "groups by first index at depth 1" do
      rows = [
        row.call(1, [0, 0]),
        row.call(2, [0, 1]),
        row.call(3, [1, 0]),
        row.call(4, [1, 1])
      ]

      result = described_class.group_rows(rows, 1)

      expect(result).to eq([
                             [1, 2],
                             [3, 4]
                           ])
    end

    it "creates nested structure at depth 2" do
      rows = [
        row.call(1, [0, 0, 0]),
        row.call(2, [0, 0, 1]),
        row.call(3, [0, 1, 0]),
        row.call(4, [1, 0, 0])
      ]

      result = described_class.group_rows(rows, 2)

      expect(result).to eq([
                             [[1, 2], [3]],
                             [[4]]
                           ])
    end

    it "handles sparse indices correctly" do
      rows = [
        row.call(1, [0, 0]),
        row.call(2, [0, 2]),
        row.call(3, [2, 0])
      ]

      result = described_class.group_rows(rows, 1)

      expect(result).to eq([
                             [1, 2],
                             [3]
                           ])
    end

    it "sorts groups by index (Done by the .vec)" do
      rows = [
        row.call(3, [2, 0]),
        row.call(1, [0, 0]),
        row.call(2, [1, 0])
      ]

      vec = Kumi::Core::IR::ExecutionEngine::Values.vec(%i[i j], rows, true)

      result = described_class.group_rows(vec[:rows], 1)

      expect(result).to eq([[1], [2], [3]])
    end
  end
end
