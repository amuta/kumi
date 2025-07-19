# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Input::Validator do
  describe ".validate_context" do
    let(:input_meta) do
      {
        age: { type: :integer, domain: 18..65 },
        score: { type: :float, domain: 0.0..100.0 },
        name: { type: :string, domain: nil },
        active: { type: :boolean, domain: nil },
        tags: { type: { array: :string }, domain: nil },
        metadata: { type: { hash: %i[string any] }, domain: nil },
        untyped: { type: :any, domain: nil }
      }
    end

    context "with valid input" do
      it "returns empty violations array" do
        context = {
          age: 25,
          score: 85.0,
          name: "John",
          active: true,
          tags: %w[work ruby],
          metadata: { "version" => "1.0" },
          untyped: { any: "value" }
        }
        violations = described_class.validate_context(context, input_meta)
        expect(violations).to be_empty
      end

      it "allows integer for float fields" do
        context = { age: 25, score: 85, name: "John", active: true, tags: [], metadata: {} }
        violations = described_class.validate_context(context, input_meta)
        expect(violations).to be_empty
      end
    end

    context "with type violations" do
      it "catches basic type mismatches" do
        context = {
          age: "25",       # String instead of integer
          score: 85.0,     # Correct
          name: "John",    # Correct
          active: "true",  # String instead of boolean
          tags: [],       # Correct
          metadata: {}    # Correct
        }
        violations = described_class.validate_context(context, input_meta)

        expect(violations.size).to eq(2)
        type_violations = violations.select { |v| v[:type] == :type_violation }
        expect(type_violations.size).to eq(2)

        fields = type_violations.map { |v| v[:field] }
        expect(fields).to contain_exactly(:age, :active)
      end

      it "validates array element types" do
        context = {
          age: 25,
          score: 85.0,
          name: "John",
          active: true,
          tags: ["tag1", 123, "tag3"], # Mixed types
          metadata: {}
        }
        violations = described_class.validate_context(context, input_meta)

        expect(violations.size).to eq(1)
        violation = violations.first
        expect(violation[:type]).to eq(:type_violation)
        expect(violation[:field]).to eq(:tags)
        expect(violation[:message]).to include("array(string)")
      end

      it "validates hash key and value types" do
        context = {
          age: 25,
          score: 85.0,
          name: "John",
          active: true,
          tags: [],
          metadata: { symbol_key: "value" } # Wrong key type
        }
        violations = described_class.validate_context(context, input_meta)

        expect(violations.size).to eq(1)
        violation = violations.first
        expect(violation[:type]).to eq(:type_violation)
        expect(violation[:field]).to eq(:metadata)
      end
    end

    context "with domain violations" do
      it "catches domain violations for correct types" do
        context = {
          age: 16,         # Correct type, wrong domain
          score: 110.0,    # Correct type, wrong domain
          name: "John",    # Correct
          active: true,    # Correct
          tags: [],       # Correct
          metadata: {}    # Correct
        }
        violations = described_class.validate_context(context, input_meta)

        expect(violations.size).to eq(2)
        domain_violations = violations.select { |v| v[:type] == :domain_violation }
        expect(domain_violations.size).to eq(2)

        fields = domain_violations.map { |v| v[:field] }
        expect(fields).to contain_exactly(:age, :score)
      end
    end

    context "with mixed violations" do
      it "prioritizes type checking over domain checking" do
        context = {
          age: "16",       # Wrong type AND would be wrong domain
          score: "high",   # Wrong type AND would be wrong domain
          name: "John",    # Correct
          active: true,    # Correct
          tags: [],       # Correct
          metadata: {}    # Correct
        }
        violations = described_class.validate_context(context, input_meta)

        expect(violations.size).to eq(2)
        # Should only get type violations, not domain violations
        expect(violations.all? { |v| v[:type] == :type_violation }).to be true

        fields = violations.map { |v| v[:field] }
        expect(fields).to contain_exactly(:age, :score)
      end
    end

    context "with fields not in input_meta" do
      it "ignores extra fields" do
        context = { age: 25, extra_field: "ignored" }
        violations = described_class.validate_context(context, input_meta)
        expect(violations).to be_empty
      end
    end

    context "with fields without types or domains" do
      it "skips validation for untyped fields with no constraints" do
        context = { untyped: "any value" }
        violations = described_class.validate_context(context, input_meta)
        expect(violations).to be_empty
      end
    end
  end

  describe ".type_matches?" do
    context "with primitive types" do
      it "matches integer types" do
        expect(described_class.type_matches?(42, :integer)).to be true
        expect(described_class.type_matches?("42", :integer)).to be false
        expect(described_class.type_matches?(42.0, :integer)).to be false
      end

      it "matches float types (including integers)" do
        expect(described_class.type_matches?(42.5, :float)).to be true
        expect(described_class.type_matches?(42, :float)).to be true
        expect(described_class.type_matches?("42.5", :float)).to be false
      end

      it "matches string types" do
        expect(described_class.type_matches?("hello", :string)).to be true
        expect(described_class.type_matches?(42, :string)).to be false
      end

      it "matches boolean types" do
        expect(described_class.type_matches?(true, :boolean)).to be true
        expect(described_class.type_matches?(false, :boolean)).to be true
        expect(described_class.type_matches?("true", :boolean)).to be false
        expect(described_class.type_matches?(1, :boolean)).to be false
      end

      it "matches symbol types" do
        expect(described_class.type_matches?(:symbol, :symbol)).to be true
        expect(described_class.type_matches?("symbol", :symbol)).to be false
      end

      it "matches any type" do
        expect(described_class.type_matches?("anything", :any)).to be true
        expect(described_class.type_matches?(42, :any)).to be true
        expect(described_class.type_matches?(nil, :any)).to be true
      end
    end

    context "with array types" do
      it "matches homogeneous arrays" do
        array_type = { array: :string }
        expect(described_class.type_matches?(%w[a b c], array_type)).to be true
        expect(described_class.type_matches?(["a", 1, "c"], array_type)).to be false
        expect(described_class.type_matches?("not_array", array_type)).to be false
      end

      it "matches arrays with any element type" do
        array_type = { array: :any }
        expect(described_class.type_matches?([1, "a", true], array_type)).to be true
        expect(described_class.type_matches?([], array_type)).to be true
      end
    end

    context "with hash types" do
      it "matches homogeneous hashes" do
        hash_type = { hash: %i[string integer] }
        expect(described_class.type_matches?({ "a" => 1, "b" => 2 }, hash_type)).to be true
        expect(described_class.type_matches?({ "a" => "not_int" }, hash_type)).to be false
        expect(described_class.type_matches?({ symbol: 1 }, hash_type)).to be false
      end

      it "matches hashes with any key/value types" do
        hash_type = { hash: %i[any any] }
        expect(described_class.type_matches?({ "a" => 1, :b => "c" }, hash_type)).to be true
        expect(described_class.type_matches?({}, hash_type)).to be true
      end
    end
  end

  describe ".infer_type" do
    it "infers primitive types correctly" do
      expect(described_class.infer_type(42)).to eq(:integer)
      expect(described_class.infer_type(42.5)).to eq(:float)
      expect(described_class.infer_type("hello")).to eq(:string)
      expect(described_class.infer_type(true)).to eq(:boolean)
      expect(described_class.infer_type(false)).to eq(:boolean)
      expect(described_class.infer_type(:symbol)).to eq(:symbol)
    end

    it "infers collection types" do
      expect(described_class.infer_type([])).to eq({ array: :mixed })
      expect(described_class.infer_type({})).to eq({ hash: %i[mixed mixed] })
    end

    it "handles unknown types" do
      expect(described_class.infer_type(Object.new)).to eq(:unknown)
    end
  end

  describe ".format_type" do
    it "formats primitive types" do
      expect(described_class.format_type(:integer)).to eq("integer")
      expect(described_class.format_type(:string)).to eq("string")
    end

    it "formats array types" do
      expect(described_class.format_type({ array: :string })).to eq("array(string)")
      expect(described_class.format_type({ array: :any })).to eq("array(any)")
    end

    it "formats hash types" do
      expect(described_class.format_type({ hash: %i[string integer] })).to eq("hash(string, integer)")
      expect(described_class.format_type({ hash: %i[any any] })).to eq("hash(any, any)")
    end
  end
end
