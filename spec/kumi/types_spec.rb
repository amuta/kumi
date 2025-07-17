# frozen_string_literal: true

require "set"
require "date"

RSpec.describe Kumi::Types do
  describe "primitive types" do
    it "defines all expected primitive types" do
      expect(Kumi::Types::INT).to be_a(Kumi::Types::Primitive)
      expect(Kumi::Types::FLOAT).to be_a(Kumi::Types::Primitive)
      expect(Kumi::Types::STRING).to be_a(Kumi::Types::Primitive)
      expect(Kumi::Types::BOOL).to be_a(Kumi::Types::Primitive)
      expect(Kumi::Types::DATE).to be_a(Kumi::Types::Primitive)
      expect(Kumi::Types::TIME).to be_a(Kumi::Types::Primitive)
      expect(Kumi::Types::DATETIME).to be_a(Kumi::Types::Primitive)
      expect(Kumi::Types::SYMBOL).to be_a(Kumi::Types::Primitive)
      expect(Kumi::Types::REGEXP).to be_a(Kumi::Types::Primitive)
      expect(Kumi::Types::UUID).to be_a(Kumi::Types::Primitive)
    end

    it "supports comparison" do
      expect(Kumi::Types::FLOAT <=> Kumi::Types::INT).to eq(-1)
      expect(Kumi::Types::STRING <=> Kumi::Types::STRING).to eq(0)
    end

    it "has proper string representation" do
      expect(Kumi::Types::INT.to_s).to eq("int")
      expect(Kumi::Types::STRING.to_s).to eq("string")
    end
  end

  describe "union types" do
    it "creates unions with | operator" do
      union = Kumi::Types::INT | Kumi::Types::FLOAT
      expect(union).to be_a(Kumi::Types::Union)
      expect(union.left).to eq(Kumi::Types::INT)
      expect(union.right).to eq(Kumi::Types::FLOAT)
    end

    it "has proper string representation" do
      union = Kumi::Types::INT | Kumi::Types::FLOAT
      expect(union.to_s).to eq("int | float")
    end
  end

  describe "parametric types" do
    describe "ArrayOf" do
      it "creates typed arrays" do
        int_array = described_class.array(Kumi::Types::INT)
        expect(int_array).to be_a(Kumi::Types::ArrayOf)
        expect(int_array.elem).to eq(Kumi::Types::INT)
        expect(int_array.to_s).to eq("array<int>")
      end
    end

    describe "SetOf" do
      it "creates typed sets" do
        string_set = described_class.set(Kumi::Types::STRING)
        expect(string_set).to be_a(Kumi::Types::SetOf)
        expect(string_set.elem).to eq(Kumi::Types::STRING)
        expect(string_set.to_s).to eq("set<string>")
      end
    end

    describe "HashOf" do
      it "creates typed hashes" do
        string_int_hash = described_class.hash(Kumi::Types::STRING, Kumi::Types::INT)
        expect(string_int_hash).to be_a(Kumi::Types::HashOf)
        expect(string_int_hash.key).to eq(Kumi::Types::STRING)
        expect(string_int_hash.val).to eq(Kumi::Types::INT)
        expect(string_int_hash.to_s).to eq("hash<string,int>")
      end
    end
  end

  describe "type inference from values" do
    it "infers correct types from Ruby values" do
      expect(described_class.infer_from_value(42)).to eq(Kumi::Types::INT)
      expect(described_class.infer_from_value(3.14)).to eq(Kumi::Types::FLOAT)
      expect(described_class.infer_from_value("hello")).to eq(Kumi::Types::STRING)
      expect(described_class.infer_from_value(true)).to eq(Kumi::Types::BOOL)
      expect(described_class.infer_from_value(false)).to eq(Kumi::Types::BOOL)
      expect(described_class.infer_from_value(:symbol)).to eq(Kumi::Types::SYMBOL)
      expect(described_class.infer_from_value(/regex/)).to eq(Kumi::Types::REGEXP)
    end

    it "infers collection types" do
      expect(described_class.infer_from_value([1, 2, 3])).to be_a(Kumi::Types::ArrayOf)
      expect(described_class.infer_from_value(Set.new([1, 2]))).to be_a(Kumi::Types::SetOf)
      expect(described_class.infer_from_value({ a: 1 })).to be_a(Kumi::Types::HashOf)
    end
  end

  describe "type unification" do
    it "unifies identical types" do
      result = described_class.unify(Kumi::Types::INT, Kumi::Types::INT)
      expect(result).to eq(Kumi::Types::INT)
    end

    it "unifies with base type" do
      base = Kumi::Types::Base.new
      result = described_class.unify(Kumi::Types::INT, base)
      expect(result).to eq(Kumi::Types::INT)
    end

    it "creates unions for different primitive types" do
      result = described_class.unify(Kumi::Types::INT, Kumi::Types::STRING)
      expect(result).to be_a(Kumi::Types::Union)
    end

    it "unifies array types" do
      arr1 = described_class.array(Kumi::Types::INT)
      arr2 = described_class.array(Kumi::Types::FLOAT)
      result = described_class.unify(arr1, arr2)
      expect(result).to be_a(Kumi::Types::ArrayOf)
      expect(result.elem).to be_a(Kumi::Types::Union)
    end
  end

  describe "type compatibility" do
    it "checks basic compatibility" do
      expect(described_class.compatible?(Kumi::Types::INT, Kumi::Types::INT)).to be true
      expect(described_class.compatible?(Kumi::Types::INT, Kumi::Types::STRING)).to be false
    end

    it "handles base type compatibility" do
      base = Kumi::Types::Base.new
      expect(described_class.compatible?(Kumi::Types::INT, base)).to be true
      expect(described_class.compatible?(base, Kumi::Types::INT)).to be true
    end

    it "handles union type compatibility" do
      union = Kumi::Types::INT | Kumi::Types::FLOAT
      expect(described_class.compatible?(Kumi::Types::INT, union)).to be true
      expect(described_class.compatible?(Kumi::Types::STRING, union)).to be false
    end

    it "handles numeric compatibility" do
      expect(described_class.compatible?(Kumi::Types::INT, Kumi::Types::DECIMAL)).to be true
      expect(described_class.compatible?(Kumi::Types::FLOAT, Kumi::Types::DECIMAL)).to be true
    end
  end

  describe "NUMERIC constant" do
    it "is a union of INT and FLOAT" do
      expect(Kumi::Types::NUMERIC).to be_a(Kumi::Types::Union)
      expect([Kumi::Types::NUMERIC.left, Kumi::Types::NUMERIC.right]).to contain_exactly(Kumi::Types::INT, Kumi::Types::FLOAT)
    end
  end
end
