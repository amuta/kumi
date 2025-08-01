# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Types::Validator do
  describe ".valid_type?" do
    context "with primitive types" do
      it "validates primitive type symbols" do
        %i[string integer float boolean any symbol regexp time date datetime].each do |type|
          expect(described_class.valid_type?(type)).to be true
        end
      end

      it "rejects invalid type symbols" do
        expect(described_class.valid_type?(:invalid)).to be false
        expect(described_class.valid_type?(:unknown)).to be false
      end
    end

    context "with array types" do
      it "validates simple array types" do
        array_type = { array: :string }
        expect(described_class.valid_type?(array_type)).to be true
      end

      it "validates nested array types" do
        nested_array = { array: { array: :integer } }
        expect(described_class.valid_type?(nested_array)).to be true
      end

      it "rejects array types with invalid elements" do
        invalid_array = { array: :invalid }
        expect(described_class.valid_type?(invalid_array)).to be false
      end
    end

    context "with hash types" do
      it "validates simple hash types" do
        hash_type = { hash: %i[string integer] }
        expect(described_class.valid_type?(hash_type)).to be true
      end

      it "validates nested hash types" do
        nested_hash = { hash: [:string, { array: :float }] }
        expect(described_class.valid_type?(nested_hash)).to be true
      end

      it "rejects hash types with invalid structure" do
        invalid_hash = { hash: [:string] }
        expect(described_class.valid_type?(invalid_hash)).to be false
      end

      it "rejects hash types with invalid key/value types" do
        invalid_hash = { hash: %i[invalid string] }
        expect(described_class.valid_type?(invalid_hash)).to be false
      end
    end

    context "with other types" do
      it "rejects non-hash, non-symbol types" do
        expect(described_class.valid_type?("string")).to be false
        expect(described_class.valid_type?(42)).to be false
        expect(described_class.valid_type?(nil)).to be false
      end
    end
  end

  describe ".array_type?" do
    it "identifies array types" do
      expect(described_class.array_type?({ array: :string })).to be true
      expect(described_class.array_type?({ array: { array: :integer } })).to be true
    end

    it "rejects non-array types" do
      expect(described_class.array_type?(:string)).to be false
      expect(described_class.array_type?({ hash: %i[string integer] })).to be false
    end
  end

  describe ".hash_type?" do
    it "identifies hash types" do
      expect(described_class.hash_type?({ hash: %i[string integer] })).to be true
      expect(described_class.hash_type?({ hash: [:any, { array: :float }] })).to be true
    end

    it "rejects non-hash types" do
      expect(described_class.hash_type?(:string)).to be false
      expect(described_class.hash_type?({ array: :string })).to be false
    end
  end

  describe ".primitive_type?" do
    it "identifies primitive types" do
      %i[string integer float boolean any symbol regexp time date datetime].each do |type|
        expect(described_class.primitive_type?(type)).to be true
      end
    end

    it "rejects non-primitive types" do
      expect(described_class.primitive_type?({ array: :string })).to be false
      expect(described_class.primitive_type?(:invalid)).to be false
    end
  end
end
