# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Types::Validator do
  describe ".valid_kind?" do
    it "validates scalar kind symbols" do
      %i[string integer float boolean any symbol regexp time date datetime null].each do |type|
        expect(described_class.valid_kind?(type)).to be true
      end
    end

    it "rejects invalid kind symbols" do
      expect(described_class.valid_kind?(:invalid)).to be false
      expect(described_class.valid_kind?(:unknown)).to be false
      expect(described_class.valid_kind?(:array)).to be false
      expect(described_class.valid_kind?(:hash)).to be false
    end
  end

  describe ".valid_type?" do
    context "with scalar type symbols" do
      it "validates scalar kind symbols" do
        %i[string integer float boolean any symbol regexp time date datetime].each do |type|
          expect(described_class.valid_type?(type)).to be true
        end
      end

      it "rejects invalid type symbols" do
        expect(described_class.valid_type?(:invalid)).to be false
        expect(described_class.valid_type?(:unknown)).to be false
      end
    end

    context "with Type objects" do
      it "validates ScalarType objects" do
        scalar_type = Kumi::Core::Types.scalar(:string)
        expect(described_class.valid_type?(scalar_type)).to be true
      end

      it "validates ArrayType objects" do
        array_type = Kumi::Core::Types.array(Kumi::Core::Types.scalar(:integer))
        expect(described_class.valid_type?(array_type)).to be true
      end

      it "validates TupleType objects" do
        tuple_type = Kumi::Core::Types.tuple([
                                               Kumi::Core::Types.scalar(:string),
                                               Kumi::Core::Types.scalar(:integer)
                                             ])
        expect(described_class.valid_type?(tuple_type)).to be true
      end
    end

    context "with other types" do
      it "rejects non-symbol, non-Type objects" do
        expect(described_class.valid_type?("string")).to be false
        expect(described_class.valid_type?(42)).to be false
        expect(described_class.valid_type?(nil)).to be false
        expect(described_class.valid_type?({})).to be false
      end
    end
  end
end
