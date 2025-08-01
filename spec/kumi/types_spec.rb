# frozen_string_literal: true

require "set"
require "date"

RSpec.describe Kumi::Core::Types do
  describe "type validation" do
    it "validates primitive type symbols" do
      expect(described_class.valid_type?(:string)).to be true
      expect(described_class.valid_type?(:integer)).to be true
      expect(described_class.valid_type?(:float)).to be true
      expect(described_class.valid_type?(:boolean)).to be true
      expect(described_class.valid_type?(:any)).to be true
      expect(described_class.valid_type?(:symbol)).to be true
      expect(described_class.valid_type?(:regexp)).to be true
      expect(described_class.valid_type?(:time)).to be true
      expect(described_class.valid_type?(:date)).to be true
      expect(described_class.valid_type?(:datetime)).to be true
    end

    it "rejects invalid type symbols" do
      expect(described_class.valid_type?(:invalid)).to be false
      expect(described_class.valid_type?("string")).to be false
      expect(described_class.valid_type?(42)).to be false
    end

    it "validates complex types" do
      expect(described_class.valid_type?({ array: :string })).to be true
      expect(described_class.valid_type?({ hash: %i[string integer] })).to be true
      expect(described_class.valid_type?({ array: :invalid })).to be false
      expect(described_class.valid_type?({ hash: [:string] })).to be false
    end
  end

  describe "type normalization" do
    it "normalizes valid symbols" do
      expect(described_class.normalize(:string)).to eq(:string)
      expect(described_class.normalize(:integer)).to eq(:integer)
    end

    it "normalizes strings to symbols" do
      expect(described_class.normalize("string")).to eq(:string)
      expect(described_class.normalize("integer")).to eq(:integer)
    end

    it "normalizes complex types" do
      expect(described_class.normalize({ array: :string })).to eq({ array: :string })
      expect(described_class.normalize({ hash: %i[string integer] })).to eq({ hash: %i[string integer] })
    end

    it "raises error for invalid types" do
      expect { described_class.normalize(:invalid) }.to raise_error(ArgumentError, /Invalid type symbol/)
      expect { described_class.normalize("invalid") }.to raise_error(ArgumentError, /Invalid type string/)
      expect { described_class.normalize(42) }.to raise_error(ArgumentError, /Type must be a symbol/)
    end
  end

  describe "helper functions" do
    describe "array" do
      it "creates array types" do
        result = described_class.array(:string)
        expect(result).to eq({ array: :string })
      end

      it "raises error for invalid element types" do
        expect { described_class.array(:invalid) }.to raise_error(ArgumentError, /Invalid array element type/)
      end
    end

    describe "hash" do
      it "creates hash types" do
        result = described_class.hash(:string, :integer)
        expect(result).to eq({ hash: %i[string integer] })
      end

      it "raises error for invalid key/value types" do
        expect { described_class.hash(:invalid, :string) }.to raise_error(ArgumentError, /Invalid hash key type/)
        expect { described_class.hash(:string, :invalid) }.to raise_error(ArgumentError, /Invalid hash value type/)
      end
    end
  end

  describe "type compatibility" do
    it "checks basic compatibility" do
      expect(described_class.compatible?(:string, :string)).to be true
      expect(described_class.compatible?(:integer, :string)).to be false
    end

    it "handles :any compatibility" do
      expect(described_class.compatible?(:any, :string)).to be true
      expect(described_class.compatible?(:string, :any)).to be true
    end

    it "handles numeric compatibility" do
      expect(described_class.compatible?(:integer, :float)).to be true
      expect(described_class.compatible?(:float, :integer)).to be true
    end

    it "handles array compatibility" do
      arr1 = { array: :string }
      arr2 = { array: :string }
      arr3 = { array: :integer }

      expect(described_class.compatible?(arr1, arr2)).to be true
      expect(described_class.compatible?(arr1, arr3)).to be false
    end

    it "handles hash compatibility" do
      hash1 = { hash: %i[string integer] }
      hash2 = { hash: %i[string integer] }
      hash3 = { hash: %i[string string] }

      expect(described_class.compatible?(hash1, hash2)).to be true
      expect(described_class.compatible?(hash1, hash3)).to be false
    end
  end

  describe "type unification" do
    it "unifies identical types" do
      expect(described_class.unify(:string, :string)).to eq(:string)
    end

    it "unifies with :any" do
      expect(described_class.unify(:any, :string)).to eq(:string)
      expect(described_class.unify(:string, :any)).to eq(:string)
    end

    it "unifies numeric types" do
      expect(described_class.unify(:integer, :float)).to eq(:float)
      expect(described_class.unify(:float, :integer)).to eq(:float)
      expect(described_class.unify(:integer, :integer)).to eq(:integer)
    end

    it "unifies array types" do
      arr1 = { array: :integer }
      arr2 = { array: :float }
      result = described_class.unify(arr1, arr2)
      expect(result).to eq({ array: :float })
    end

    it "unifies hash types" do
      hash1 = { hash: %i[string integer] }
      hash2 = { hash: %i[string float] }
      result = described_class.unify(hash1, hash2)
      expect(result).to eq({ hash: %i[string float] })
    end

    it "falls back to :any for incompatible types" do
      expect(described_class.unify(:string, :integer)).to eq(:any)
    end
  end

  describe "type inference from values" do
    it "infers primitive types from Ruby values" do
      expect(described_class.infer_from_value(42)).to eq(:integer)
      expect(described_class.infer_from_value(3.14)).to eq(:float)
      expect(described_class.infer_from_value("hello")).to eq(:string)
      expect(described_class.infer_from_value(true)).to eq(:boolean)
      expect(described_class.infer_from_value(false)).to eq(:boolean)
      expect(described_class.infer_from_value(:symbol)).to eq(:symbol)
      expect(described_class.infer_from_value(/regex/)).to eq(:regexp)
    end

    it "infers array types" do
      expect(described_class.infer_from_value([1, 2, 3])).to eq({ array: :integer })
      expect(described_class.infer_from_value([])).to eq({ array: :any })
    end

    it "infers hash types" do
      expect(described_class.infer_from_value({ "key" => 42 })).to eq({ hash: %i[string integer] })
      expect(described_class.infer_from_value({})).to eq({ hash: %i[any any] })
    end

    it "handles unknown types" do
      expect(described_class.infer_from_value(Object.new)).to eq(:any)
    end
  end

  describe "string representation" do
    it "converts primitive types to strings" do
      expect(described_class.type_to_s(:string)).to eq("string")
      expect(described_class.type_to_s(:integer)).to eq("integer")
    end

    it "converts array types to strings" do
      expect(described_class.type_to_s({ array: :string })).to eq("array(string)")
    end

    it "converts hash types to strings" do
      expect(described_class.type_to_s({ hash: %i[string integer] })).to eq("hash(string, integer)")
    end
  end

  describe "legacy compatibility" do
    it "provides legacy constants" do
      expect(Kumi::Core::Types::STRING).to eq(:string)
      expect(Kumi::Core::Types::INT).to eq(:integer)
      expect(Kumi::Core::Types::FLOAT).to eq(:float)
      expect(Kumi::Core::Types::BOOL).to eq(:boolean)
      expect(Kumi::Core::Types::ANY).to eq(:any)
    end

    it "handles legacy coercion" do
      expect(described_class.coerce(:string)).to eq(:string)
      expect(described_class.coerce(Kumi::Core::Types::STRING)).to eq(:string)
      expect(described_class.coerce(Kumi::Core::Types::INT)).to eq(:integer)
    end
  end
end
