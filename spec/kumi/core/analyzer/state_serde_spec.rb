# frozen_string_literal: true

RSpec.describe Kumi::Core::Analyzer::StateSerde do
  let(:simple_state) do
    Kumi::Core::Analyzer::AnalysisState.new(
      test: "data",
      count: 42,
      enabled: true,
      tags: Set.new([:a, :b, :c]),
      metadata: { key: :value }
    )
  end

  describe "marshal round-trip" do
    it "preserves exact state data" do
      marshaled = described_class.dump_marshal(simple_state)
      restored = described_class.load_marshal(marshaled)
      
      expect(restored.to_h).to eq(simple_state.to_h)
      expect(restored).to be_a(Kumi::Core::Analyzer::AnalysisState)
    end

    it "includes version information" do
      marshaled = described_class.dump_marshal(simple_state)
      payload = Marshal.load(marshaled)
      
      expect(payload).to be_a(Hash)
      expect(payload[:v]).to eq(1)
      expect(payload[:data]).to eq(simple_state.to_h)
    end

    it "handles complex nested structures" do
      complex_state = Kumi::Core::Analyzer::AnalysisState.new(
        nested: {
          arrays: [[1, 2], [3, 4]],
          sets: Set.new([Set.new([:x]), Set.new([:y])]),
          symbols: [:a, :b, :c]
        }
      )
      
      marshaled = described_class.dump_marshal(complex_state)
      restored = described_class.load_marshal(marshaled)
      
      expect(restored.to_h).to eq(complex_state.to_h)
    end
  end

  describe "json encoding/decoding" do
    it "encodes symbols with $sym wrapper" do
      result = described_class.encode_json_safe(:test_symbol)
      expect(result).to eq({ "$sym" => "test_symbol" })
    end

    it "encodes sets with $set wrapper" do
      set = Set.new([1, 2, 3])
      result = described_class.encode_json_safe(set)
      expect(result).to eq({ "$set" => [1, 2, 3] })
    end

    it "encodes nested sets and symbols" do
      nested_set = Set.new([:a, :b])
      result = described_class.encode_json_safe(nested_set)
      expect(result).to eq({ "$set" => [{ "$sym" => "a" }, { "$sym" => "b" }] })
    end

    it "converts hash keys to strings" do
      hash = { key: "value", other: 42 }
      result = described_class.encode_json_safe(hash)
      expect(result).to eq({ "key" => "value", "other" => 42 })
    end

    it "handles arrays recursively" do
      array = [:symbol, Set.new([1, 2]), { nested: :value }]
      result = described_class.encode_json_safe(array)
      expect(result).to eq([
        { "$sym" => "symbol" },
        { "$set" => [1, 2] },
        { "nested" => { "$sym" => "value" } }
      ])
    end
  end

  describe "json decoding" do
    it "decodes $sym wrappers back to symbols" do
      encoded = { "$sym" => "test_symbol" }
      result = described_class.decode_json_safe(encoded)
      expect(result).to eq(:test_symbol)
    end

    it "decodes $set wrappers back to sets" do
      encoded = { "$set" => [1, 2, 3] }
      result = described_class.decode_json_safe(encoded)
      expect(result).to eq(Set.new([1, 2, 3]))
    end

    it "converts string keys back to symbols" do
      encoded = { "key" => "value", "other" => 42 }
      result = described_class.decode_json_safe(encoded)
      expect(result).to eq({ key: "value", other: 42 })
    end

    it "handles nested structures" do
      encoded = {
        "data" => { "$set" => [{ "$sym" => "a" }, { "$sym" => "b" }] },
        "meta" => { "nested" => { "$sym" => "value" } }
      }
      result = described_class.decode_json_safe(encoded)
      expect(result).to eq({
        data: Set.new([:a, :b]),
        meta: { nested: :value }
      })
    end
  end

  describe "json round-trip" do
    it "preserves basic state data" do
      json_str = described_class.dump_json(simple_state)
      restored = described_class.load_json(json_str)
      
      expect(restored.to_h).to eq(simple_state.to_h)
      expect(restored).to be_a(Kumi::Core::Analyzer::AnalysisState)
    end

    it "preserves sets and symbols" do
      state_with_sets = Kumi::Core::Analyzer::AnalysisState.new(
        tags: Set.new([:important, :verified]),
        config: { mode: :development, flags: Set.new([:debug, :verbose]) }
      )
      
      json_str = described_class.dump_json(state_with_sets)
      restored = described_class.load_json(json_str)
      
      expect(restored.to_h).to eq(state_with_sets.to_h)
    end

    it "produces readable json with pretty formatting" do
      json_str = described_class.dump_json(simple_state, pretty: true)
      
      expect(json_str).to include("\n")  # Pretty-formatted
      expect(json_str).to include('"test": "data"')
      expect(json_str).to include('"count": 42')
      
      # Should be parseable back
      restored = described_class.load_json(json_str)
      expect(restored.to_h).to eq(simple_state.to_h)
    end

    it "produces compact json without pretty formatting" do
      json_str = described_class.dump_json(simple_state, pretty: false)
      
      expect(json_str).not_to include("\n")  # Compact
      
      # Should still be parseable
      restored = described_class.load_json(json_str)
      expect(restored.to_h).to eq(simple_state.to_h)
    end
  end

  describe "IR object handling" do
    # These tests would require actual IR objects to be meaningful
    # For now, we'll test the structure exists
    
    it "has IR encoding capability" do
      # Test that the encode method handles IR objects without crashing
      # when they don't exist in current test state
      expect { described_class.encode_json_safe("not an IR object") }.not_to raise_error
    end
  end
end