# frozen_string_literal: true

require "spec_helper"
require "bigdecimal"

RSpec.describe Kumi::Core::Types::Normalizer do
  describe ".normalize" do
    let(:string_type) { Kumi::Core::Types.scalar(:string) }
    let(:integer_type) { Kumi::Core::Types.scalar(:integer) }
    let(:float_type) { Kumi::Core::Types.scalar(:float) }
    let(:decimal_type) { Kumi::Core::Types.scalar(:decimal) }
    let(:boolean_type) { Kumi::Core::Types.scalar(:boolean) }
    let(:any_type) { Kumi::Core::Types.scalar(:any) }

    context "with symbols" do
      it "returns valid type symbols as Type objects" do
        expect(described_class.normalize(:string)).to eq(string_type)
        expect(described_class.normalize(:integer)).to eq(integer_type)
        expect(described_class.normalize(:float)).to eq(float_type)
        expect(described_class.normalize(:decimal)).to eq(decimal_type)
        expect(described_class.normalize(:boolean)).to eq(boolean_type)
        expect(described_class.normalize(:any)).to eq(any_type)
      end

      it "raises error for invalid type symbols" do
        expect do
          described_class.normalize(:invalid)
        end.to raise_error(ArgumentError, /Invalid type symbol/)
      end
    end

    context "with strings" do
      it "converts valid type strings to Type objects" do
        expect(described_class.normalize("string")).to eq(string_type)
        expect(described_class.normalize("integer")).to eq(integer_type)
        expect(described_class.normalize("decimal")).to eq(decimal_type)
        expect(described_class.normalize("boolean")).to eq(boolean_type)
      end

      it "raises error for invalid type strings" do
        expect do
          described_class.normalize("invalid")
        end.to raise_error(ArgumentError, /Invalid type string/)
      end
    end

    context "with hashes" do
      it "raises error for hash-based types" do
        expect do
          described_class.normalize({ array: :string })
        end.to raise_error(ArgumentError, /Hash-based types no longer supported/)
      end
    end

    context "with Ruby classes" do
      it "converts Integer class to integer Type object" do
        expect(described_class.normalize(Integer)).to eq(integer_type)
      end

      it "converts String class to string Type object" do
        expect(described_class.normalize(String)).to eq(string_type)
      end

      it "converts Float class to float Type object" do
        expect(described_class.normalize(Float)).to eq(float_type)
      end

      it "converts BigDecimal class to decimal Type object" do
        expect(described_class.normalize(BigDecimal)).to eq(decimal_type)
      end

      it "converts TrueClass and FalseClass to boolean Type objects" do
        expect(described_class.normalize(TrueClass)).to eq(boolean_type)
        expect(described_class.normalize(FalseClass)).to eq(boolean_type)
      end

      it "raises helpful error for Array class" do
        expect do
          described_class.normalize(Array)
        end.to raise_error(ArgumentError, /Use array\(:type\) helper/)
      end

      it "raises helpful error for Hash class" do
        expect do
          described_class.normalize(Hash)
        end.to raise_error(ArgumentError, /Use scalar\(:hash\)/)
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

    context "with Type objects" do
      it "returns Type objects unchanged" do
        type_obj = Kumi::Core::Types.scalar(:string)
        expect(described_class.normalize(type_obj)).to eq(type_obj)
      end
    end
  end
end
