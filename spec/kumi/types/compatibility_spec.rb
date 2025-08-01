# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Types::Compatibility do
  describe ".compatible?" do
    context "with identical types" do
      it "considers identical primitive types compatible" do
        expect(described_class.compatible?(:string, :string)).to be true
        expect(described_class.compatible?(:integer, :integer)).to be true
        expect(described_class.compatible?(:boolean, :boolean)).to be true
      end

      it "considers identical complex types compatible" do
        array_type = { array: :string }
        expect(described_class.compatible?(array_type, array_type)).to be true

        hash_type = { hash: %i[string integer] }
        expect(described_class.compatible?(hash_type, hash_type)).to be true
      end
    end

    context "with :any type" do
      it "considers :any compatible with any type" do
        expect(described_class.compatible?(:any, :string)).to be true
        expect(described_class.compatible?(:string, :any)).to be true
        expect(described_class.compatible?(:any, { array: :integer })).to be true
      end
    end

    context "with numeric types" do
      it "considers integer and float compatible" do
        expect(described_class.compatible?(:integer, :float)).to be true
        expect(described_class.compatible?(:float, :integer)).to be true
      end

      it "considers integer compatible with itself" do
        expect(described_class.compatible?(:integer, :integer)).to be true
      end

      it "considers float compatible with itself" do
        expect(described_class.compatible?(:float, :float)).to be true
      end
    end

    context "with array types" do
      it "considers arrays with compatible element types compatible" do
        array1 = { array: :integer }
        array2 = { array: :float }
        expect(described_class.compatible?(array1, array2)).to be true
      end

      it "considers arrays with incompatible element types incompatible" do
        array1 = { array: :string }
        array2 = { array: :integer }
        expect(described_class.compatible?(array1, array2)).to be false
      end

      it "considers nested arrays correctly" do
        array1 = { array: { array: :integer } }
        array2 = { array: { array: :float } }
        expect(described_class.compatible?(array1, array2)).to be true
      end
    end

    context "with hash types" do
      it "considers hashes with compatible key/value types compatible" do
        hash1 = { hash: %i[string integer] }
        hash2 = { hash: %i[string float] }
        expect(described_class.compatible?(hash1, hash2)).to be true
      end

      it "considers hashes with incompatible key types incompatible" do
        hash1 = { hash: %i[string integer] }
        hash2 = { hash: %i[integer integer] }
        expect(described_class.compatible?(hash1, hash2)).to be false
      end

      it "considers hashes with incompatible value types incompatible" do
        hash1 = { hash: %i[string string] }
        hash2 = { hash: %i[string integer] }
        expect(described_class.compatible?(hash1, hash2)).to be false
      end
    end

    context "with incompatible types" do
      it "considers different primitive types incompatible" do
        expect(described_class.compatible?(:string, :boolean)).to be false
        expect(described_class.compatible?(:boolean, :symbol)).to be false
      end

      it "considers arrays and primitives incompatible" do
        expect(described_class.compatible?({ array: :string }, :string)).to be false
      end

      it "considers hashes and primitives incompatible" do
        expect(described_class.compatible?({ hash: %i[string integer] }, :string)).to be false
      end
    end
  end

  describe ".unify" do
    context "with identical types" do
      it "unifies identical types to themselves" do
        expect(described_class.unify(:string, :string)).to eq(:string)
        expect(described_class.unify(:integer, :integer)).to eq(:integer)
      end
    end

    context "with :any type" do
      it "unifies :any with other type to the more specific type" do
        expect(described_class.unify(:any, :string)).to eq(:string)
        expect(described_class.unify(:string, :any)).to eq(:string)
      end
    end

    context "with numeric types" do
      it "unifies integer and float to float" do
        expect(described_class.unify(:integer, :float)).to eq(:float)
        expect(described_class.unify(:float, :integer)).to eq(:float)
      end

      it "unifies integer with integer to integer" do
        expect(described_class.unify(:integer, :integer)).to eq(:integer)
      end
    end

    context "with array types" do
      it "unifies arrays by unifying element types" do
        array1 = { array: :integer }
        array2 = { array: :float }
        result = described_class.unify(array1, array2)
        expect(result).to eq({ array: :float })
      end

      it "unifies nested arrays correctly" do
        array1 = { array: { array: :integer } }
        array2 = { array: { array: :float } }
        result = described_class.unify(array1, array2)
        expect(result).to eq({ array: { array: :float } })
      end
    end

    context "with hash types" do
      it "unifies hashes by unifying key and value types" do
        hash1 = { hash: %i[string integer] }
        hash2 = { hash: %i[string float] }
        result = described_class.unify(hash1, hash2)
        expect(result).to eq({ hash: %i[string float] })
      end

      it "unifies complex hash structures" do
        hash1 = { hash: [:string, { array: :integer }] }
        hash2 = { hash: [:string, { array: :float }] }
        result = described_class.unify(hash1, hash2)
        expect(result).to eq({ hash: [:string, { array: :float }] })
      end
    end

    context "with incompatible types" do
      it "falls back to :any for incompatible primitive types" do
        expect(described_class.unify(:string, :boolean)).to eq(:any)
        expect(described_class.unify(:symbol, :regexp)).to eq(:any)
      end

      it "falls back to :any for mixed type categories" do
        expect(described_class.unify(:string, { array: :string })).to eq(:any)
        expect(described_class.unify({ array: :integer }, { hash: %i[string integer] })).to eq(:any)
      end
    end
  end
end
