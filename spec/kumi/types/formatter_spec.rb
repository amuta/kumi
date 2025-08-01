# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Types::Formatter do
  describe ".type_to_s" do
    context "with primitive types" do
      it "converts primitive type symbols to strings" do
        expect(described_class.type_to_s(:string)).to eq("string")
        expect(described_class.type_to_s(:integer)).to eq("integer")
        expect(described_class.type_to_s(:float)).to eq("float")
        expect(described_class.type_to_s(:boolean)).to eq("boolean")
        expect(described_class.type_to_s(:any)).to eq("any")
        expect(described_class.type_to_s(:symbol)).to eq("symbol")
        expect(described_class.type_to_s(:regexp)).to eq("regexp")
        expect(described_class.type_to_s(:time)).to eq("time")
        expect(described_class.type_to_s(:date)).to eq("date")
        expect(described_class.type_to_s(:datetime)).to eq("datetime")
      end
    end

    context "with array types" do
      it "formats simple array types" do
        array_type = { array: :string }
        expect(described_class.type_to_s(array_type)).to eq("array(string)")
      end

      it "formats nested array types" do
        nested_array = { array: { array: :integer } }
        expect(described_class.type_to_s(nested_array)).to eq("array(array(integer))")
      end

      it "formats array with hash element types" do
        complex_array = { array: { hash: %i[string integer] } }
        expect(described_class.type_to_s(complex_array)).to eq("array(hash(string, integer))")
      end
    end

    context "with hash types" do
      it "formats simple hash types" do
        hash_type = { hash: %i[string integer] }
        expect(described_class.type_to_s(hash_type)).to eq("hash(string, integer)")
      end

      it "formats nested hash types" do
        nested_hash = { hash: [:string, { hash: %i[symbol float] }] }
        expect(described_class.type_to_s(nested_hash)).to eq("hash(string, hash(symbol, float))")
      end

      it "formats hash with array value types" do
        complex_hash = { hash: [:string, { array: :boolean }] }
        expect(described_class.type_to_s(complex_hash)).to eq("hash(string, array(boolean))")
      end
    end

    context "with complex nested structures" do
      it "formats deeply nested types correctly" do
        complex_type = {
          hash: [
            :string,
            {
              array: {
                hash: [:symbol, { array: :integer }]
              }
            }
          ]
        }

        expected = "hash(string, array(hash(symbol, array(integer))))"
        expect(described_class.type_to_s(complex_type)).to eq(expected)
      end
    end

    context "with invalid or unknown structures" do
      it "falls back to to_s for unknown hash structures" do
        unknown_hash = { unknown: :structure }
        expect(described_class.type_to_s(unknown_hash)).to eq(unknown_hash.to_s)
      end

      it "handles non-hash, non-symbol types" do
        expect(described_class.type_to_s("string")).to eq("string")
        expect(described_class.type_to_s(42)).to eq("42")
        expect(described_class.type_to_s(nil)).to eq("")
      end
    end

    context "with real-world examples" do
      it "formats user data type" do
        user_type = {
          hash: [
            :symbol,
            {
              hash: %i[
                symbol
                string
              ]
            }
          ]
        }

        expected = "hash(symbol, hash(symbol, string))"
        expect(described_class.type_to_s(user_type)).to eq(expected)
      end

      it "formats configuration type" do
        config_type = {
          hash: [
            :string,
            {
              array: {
                hash: %i[string any]
              }
            }
          ]
        }

        expected = "hash(string, array(hash(string, any)))"
        expect(described_class.type_to_s(config_type)).to eq(expected)
      end
    end
  end
end
