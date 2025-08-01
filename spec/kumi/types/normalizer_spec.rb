# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Types::Normalizer do
  describe ".normalize" do
    context "with symbols" do
      it "returns valid type symbols as-is" do
        %i[string integer float boolean any symbol regexp time date datetime].each do |type|
          expect(described_class.normalize(type)).to eq(type)
        end
      end

      it "raises error for invalid type symbols" do
        expect do
          described_class.normalize(:invalid)
        end.to raise_error(ArgumentError, /Invalid type symbol/)
      end
    end

    context "with strings" do
      it "converts valid type strings to symbols" do
        expect(described_class.normalize("string")).to eq(:string)
        expect(described_class.normalize("integer")).to eq(:integer)
        expect(described_class.normalize("boolean")).to eq(:boolean)
      end

      it "raises error for invalid type strings" do
        expect do
          described_class.normalize("invalid")
        end.to raise_error(ArgumentError, /Invalid type string/)
      end
    end

    context "with hashes" do
      it "returns valid complex types as-is" do
        array_type = { array: :string }
        expect(described_class.normalize(array_type)).to eq(array_type)

        hash_type = { hash: %i[string integer] }
        expect(described_class.normalize(hash_type)).to eq(hash_type)
      end

      it "raises error for invalid complex types" do
        expect do
          described_class.normalize({ invalid: :structure })
        end.to raise_error(ArgumentError, /Invalid type hash/)
      end
    end

    context "with Ruby classes" do
      it "converts Integer class to :integer" do
        expect(described_class.normalize(Integer)).to eq(:integer)
      end

      it "converts String class to :string" do
        expect(described_class.normalize(String)).to eq(:string)
      end

      it "converts Float class to :float" do
        expect(described_class.normalize(Float)).to eq(:float)
      end

      it "converts TrueClass and FalseClass to :boolean" do
        expect(described_class.normalize(TrueClass)).to eq(:boolean)
        expect(described_class.normalize(FalseClass)).to eq(:boolean)
      end

      it "raises helpful error for Array class" do
        expect do
          described_class.normalize(Array)
        end.to raise_error(ArgumentError, /Use array\(:type\) helper/)
      end

      it "raises helpful error for Hash class" do
        expect do
          described_class.normalize(Hash)
        end.to raise_error(ArgumentError, /Use hash\(:key_type, :value_type\) helper/)
      end

      it "raises error for unsupported classes" do
        expect do
          described_class.normalize(Object)
        end.to raise_error(ArgumentError, /Unsupported class type/)
      end
    end

    context "with other types" do
      it "raises specific error for numeric inputs" do
        expect do
          described_class.normalize(42)
        end.to raise_error(ArgumentError, /Type must be a symbol/)

        expect do
          described_class.normalize(3.14)
        end.to raise_error(ArgumentError, /Type must be a symbol/)
      end

      it "raises generic error for other invalid inputs" do
        expect do
          described_class.normalize(nil)
        end.to raise_error(ArgumentError, /Invalid type input/)
      end
    end
  end

  describe ".coerce" do
    it "returns valid symbols as-is" do
      expect(described_class.coerce(:string)).to eq(:string)
      expect(described_class.coerce(:integer)).to eq(:integer)
    end

    context "with legacy constants" do
      it "converts STRING constant to :string" do
        expect(described_class.coerce(Kumi::Core::Types::STRING)).to eq(:string)
      end

      it "converts INT constant to :integer" do
        expect(described_class.coerce(Kumi::Core::Types::INT)).to eq(:integer)
      end

      it "converts FLOAT constant to :float" do
        expect(described_class.coerce(Kumi::Core::Types::FLOAT)).to eq(:float)
      end

      it "converts NUMERIC constant to :float" do
        expect(described_class.coerce(Kumi::Core::Types::NUMERIC)).to eq(:float)
      end

      it "converts BOOL constant to :boolean" do
        expect(described_class.coerce(Kumi::Core::Types::BOOL)).to eq(:boolean)
      end

      it "converts other legacy constants" do
        expect(described_class.coerce(Kumi::Core::Types::ANY)).to eq(:any)
        expect(described_class.coerce(Kumi::Core::Types::SYMBOL)).to eq(:symbol)
        expect(described_class.coerce(Kumi::Core::Types::REGEXP)).to eq(:regexp)
        expect(described_class.coerce(Kumi::Core::Types::TIME)).to eq(:time)
        expect(described_class.coerce(Kumi::Core::Types::DATE)).to eq(:date)
        expect(described_class.coerce(Kumi::Core::Types::DATETIME)).to eq(:datetime)
      end
    end

    it "falls back to normalize for non-legacy inputs" do
      expect(described_class.coerce("string")).to eq(:string)
      expect(described_class.coerce(Integer)).to eq(:integer)
    end
  end
end
