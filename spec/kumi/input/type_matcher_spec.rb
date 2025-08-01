# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Input::TypeMatcher do
  describe ".matches?" do
    context "with primitive types" do
      describe "integer type" do
        it "matches integers" do
          expect(described_class.matches?(42, :integer)).to be true
          expect(described_class.matches?(-17, :integer)).to be true
          expect(described_class.matches?(0, :integer)).to be true
        end

        it "does not match non-integers" do
          expect(described_class.matches?(42.5, :integer)).to be false
          expect(described_class.matches?("42", :integer)).to be false
          expect(described_class.matches?(true, :integer)).to be false
          expect(described_class.matches?(nil, :integer)).to be false
        end
      end

      describe "float type" do
        it "matches floats" do
          expect(described_class.matches?(42.5, :float)).to be true
          expect(described_class.matches?(-17.3, :float)).to be true
          expect(described_class.matches?(0.0, :float)).to be true
        end

        it "matches integers as valid floats" do
          expect(described_class.matches?(42, :float)).to be true
          expect(described_class.matches?(-17, :float)).to be true
          expect(described_class.matches?(0, :float)).to be true
        end

        it "does not match non-numeric types" do
          expect(described_class.matches?("42.5", :float)).to be false
          expect(described_class.matches?(true, :float)).to be false
          expect(described_class.matches?(nil, :float)).to be false
        end
      end

      describe "string type" do
        it "matches strings" do
          expect(described_class.matches?("hello", :string)).to be true
          expect(described_class.matches?("", :string)).to be true
          expect(described_class.matches?("123", :string)).to be true
        end

        it "does not match non-strings" do
          expect(described_class.matches?(123, :string)).to be false
          expect(described_class.matches?(:symbol, :string)).to be false
          expect(described_class.matches?(true, :string)).to be false
          expect(described_class.matches?(nil, :string)).to be false
        end
      end

      describe "boolean type" do
        it "matches true and false" do
          expect(described_class.matches?(true, :boolean)).to be true
          expect(described_class.matches?(false, :boolean)).to be true
        end

        it "does not match truthy/falsy values" do
          expect(described_class.matches?(1, :boolean)).to be false
          expect(described_class.matches?(0, :boolean)).to be false
          expect(described_class.matches?("true", :boolean)).to be false
          expect(described_class.matches?("false", :boolean)).to be false
          expect(described_class.matches?(nil, :boolean)).to be false
        end
      end

      describe "symbol type" do
        it "matches symbols" do
          expect(described_class.matches?(:symbol, :symbol)).to be true
          expect(described_class.matches?(:another_symbol, :symbol)).to be true
        end

        it "does not match non-symbols" do
          expect(described_class.matches?("symbol", :symbol)).to be false
          expect(described_class.matches?(123, :symbol)).to be false
          expect(described_class.matches?(true, :symbol)).to be false
        end
      end

      describe "any type" do
        it "matches any value" do
          expect(described_class.matches?("string", :any)).to be true
          expect(described_class.matches?(123, :any)).to be true
          expect(described_class.matches?(true, :any)).to be true
          expect(described_class.matches?(nil, :any)).to be true
          expect(described_class.matches?([], :any)).to be true
          expect(described_class.matches?({}, :any)).to be true
        end
      end
    end

    context "with array types" do
      describe "homogeneous arrays" do
        it "matches arrays with correct element types" do
          string_array_type = { array: :string }
          expect(described_class.matches?(%w[a b c], string_array_type)).to be true
          expect(described_class.matches?([], string_array_type)).to be true

          integer_array_type = { array: :integer }
          expect(described_class.matches?([1, 2, 3], integer_array_type)).to be true
          expect(described_class.matches?([], integer_array_type)).to be true
        end

        it "does not match arrays with incorrect element types" do
          string_array_type = { array: :string }
          expect(described_class.matches?(["a", 1, "c"], string_array_type)).to be false
          expect(described_class.matches?([1, 2, 3], string_array_type)).to be false

          integer_array_type = { array: :integer }
          expect(described_class.matches?(%w[1 2 3], integer_array_type)).to be false
          expect(described_class.matches?([1.5, 2.5], integer_array_type)).to be false
        end

        it "does not match non-arrays" do
          array_type = { array: :string }
          expect(described_class.matches?("not_array", array_type)).to be false
          expect(described_class.matches?(123, array_type)).to be false
          expect(described_class.matches?({}, array_type)).to be false
        end
      end

      describe "arrays with any element type" do
        let(:any_array_type) { { array: :any } }

        it "matches arrays with mixed element types" do
          expect(described_class.matches?([1, "a", true], any_array_type)).to be true
          expect(described_class.matches?(["string", :symbol, 42], any_array_type)).to be true
          expect(described_class.matches?([], any_array_type)).to be true
        end

        it "does not match non-arrays" do
          expect(described_class.matches?("not_array", any_array_type)).to be false
          expect(described_class.matches?(123, any_array_type)).to be false
        end
      end

      describe "nested array types" do
        it "matches arrays of arrays" do
          nested_array_type = { array: { array: :string } }
          expect(described_class.matches?([%w[a b], %w[c d]], nested_array_type)).to be true
          expect(described_class.matches?([], nested_array_type)).to be true
        end

        it "does not match incorrectly nested arrays" do
          nested_array_type = { array: { array: :string } }
          expect(described_class.matches?([["a", 1], %w[c d]], nested_array_type)).to be false
          expect(described_class.matches?(%w[not nested], nested_array_type)).to be false
        end
      end
    end

    context "with hash types" do
      describe "homogeneous hashes" do
        it "matches hashes with correct key and value types" do
          hash_type = { hash: %i[string integer] }
          expect(described_class.matches?({ "a" => 1, "b" => 2 }, hash_type)).to be true
          expect(described_class.matches?({}, hash_type)).to be true
        end

        it "does not match hashes with incorrect key types" do
          hash_type = { hash: %i[string integer] }
          expect(described_class.matches?({ symbol: 1 }, hash_type)).to be false
          expect(described_class.matches?({ 1 => 1 }, hash_type)).to be false
        end

        it "does not match hashes with incorrect value types" do
          hash_type = { hash: %i[string integer] }
          expect(described_class.matches?({ "a" => "not_int" }, hash_type)).to be false
          expect(described_class.matches?({ "a" => 1.5 }, hash_type)).to be false
        end

        it "does not match non-hashes" do
          hash_type = { hash: %i[string integer] }
          expect(described_class.matches?("not_hash", hash_type)).to be false
          expect(described_class.matches?([], hash_type)).to be false
          expect(described_class.matches?(123, hash_type)).to be false
        end
      end

      describe "hashes with any key/value types" do
        let(:any_hash_type) { { hash: %i[any any] } }

        it "matches hashes with mixed key and value types" do
          expect(described_class.matches?({ "string" => 1, :symbol => "value" }, any_hash_type)).to be true
          expect(described_class.matches?({ 1 => true, "key" => [] }, any_hash_type)).to be true
          expect(described_class.matches?({}, any_hash_type)).to be true
        end

        it "does not match non-hashes" do
          expect(described_class.matches?("not_hash", any_hash_type)).to be false
          expect(described_class.matches?([], any_hash_type)).to be false
        end
      end

      describe "hashes with mixed any/specific types" do
        it "matches hashes with any keys but specific value types" do
          hash_type = { hash: %i[any string] }
          expect(described_class.matches?({ "key" => "value", :sym => "string" }, hash_type)).to be true
          expect(described_class.matches?({ 1 => "value" }, hash_type)).to be true
          expect(described_class.matches?({ "key" => 123 }, hash_type)).to be false
        end

        it "matches hashes with specific keys but any value types" do
          hash_type = { hash: %i[string any] }
          expect(described_class.matches?({ "key" => "value", "other" => 123 }, hash_type)).to be true
          expect(described_class.matches?({ "key" => [] }, hash_type)).to be true
          expect(described_class.matches?({ symbol: "value" }, hash_type)).to be false
        end
      end

      describe "nested hash types" do
        it "matches hashes containing arrays" do
          hash_type = { hash: [:string, { array: :integer }] }
          expect(described_class.matches?({ "key" => [1, 2, 3] }, hash_type)).to be true
          expect(described_class.matches?({ "key" => [] }, hash_type)).to be true
          expect(described_class.matches?({ "key" => %w[not int] }, hash_type)).to be false
        end
      end
    end

    context "with unknown or invalid type specifications" do
      it "returns false for unknown type symbols" do
        expect(described_class.matches?("value", :unknown_type)).to be false
        expect(described_class.matches?(123, :custom_type)).to be false
      end

      it "returns false for malformed complex types" do
        expect(described_class.matches?([], { malformed: :type })).to be false
        expect(described_class.matches?({}, { invalid: "spec" })).to be false
      end

      it "returns false for non-hash complex type specifications" do
        expect(described_class.matches?([], "not_a_hash")).to be false
        expect(described_class.matches?({}, 123)).to be false
      end
    end
  end

  describe ".infer_type" do
    context "with primitive values" do
      it "infers integer type" do
        expect(described_class.infer_type(42)).to eq(:integer)
        expect(described_class.infer_type(-17)).to eq(:integer)
        expect(described_class.infer_type(0)).to eq(:integer)
      end

      it "infers float type" do
        expect(described_class.infer_type(42.5)).to eq(:float)
        expect(described_class.infer_type(-17.3)).to eq(:float)
        expect(described_class.infer_type(0.0)).to eq(:float)
      end

      it "infers string type" do
        expect(described_class.infer_type("hello")).to eq(:string)
        expect(described_class.infer_type("")).to eq(:string)
        expect(described_class.infer_type("123")).to eq(:string)
      end

      it "infers boolean type" do
        expect(described_class.infer_type(true)).to eq(:boolean)
        expect(described_class.infer_type(false)).to eq(:boolean)
      end

      it "infers symbol type" do
        expect(described_class.infer_type(:symbol)).to eq(:symbol)
        expect(described_class.infer_type(:another_symbol)).to eq(:symbol)
      end
    end

    context "with collection values" do
      it "infers mixed array type for arrays" do
        expect(described_class.infer_type([])).to eq({ array: :mixed })
        expect(described_class.infer_type([1, 2, 3])).to eq({ array: :mixed })
        expect(described_class.infer_type(%w[a b c])).to eq({ array: :mixed })
        expect(described_class.infer_type([1, "a", true])).to eq({ array: :mixed })
      end

      it "infers mixed hash type for hashes" do
        expect(described_class.infer_type({})).to eq({ hash: %i[mixed mixed] })
        expect(described_class.infer_type({ "a" => 1 })).to eq({ hash: %i[mixed mixed] })
        expect(described_class.infer_type({ sym: "value" })).to eq({ hash: %i[mixed mixed] })
        expect(described_class.infer_type({ 1 => true, "key" => [] })).to eq({ hash: %i[mixed mixed] })
      end
    end

    context "with unknown values" do
      it "infers unknown type for custom objects" do
        expect(described_class.infer_type(Object.new)).to eq(:unknown)
      end

      it "infers unknown type for nil" do
        expect(described_class.infer_type(nil)).to eq(:unknown)
      end
    end
  end

  describe ".format_type" do
    context "with primitive types" do
      it "formats symbol types as strings" do
        expect(described_class.format_type(:integer)).to eq("integer")
        expect(described_class.format_type(:string)).to eq("string")
        expect(described_class.format_type(:boolean)).to eq("boolean")
        expect(described_class.format_type(:any)).to eq("any")
      end
    end

    context "with array types" do
      it "formats simple array types" do
        expect(described_class.format_type({ array: :string })).to eq("array(string)")
        expect(described_class.format_type({ array: :integer })).to eq("array(integer)")
        expect(described_class.format_type({ array: :any })).to eq("array(any)")
      end

      it "formats nested array types" do
        nested_type = { array: { array: :string } }
        expect(described_class.format_type(nested_type)).to eq("array(array(string))")
      end
    end

    context "with hash types" do
      it "formats simple hash types" do
        expect(described_class.format_type({ hash: %i[string integer] })).to eq("hash(string, integer)")
        expect(described_class.format_type({ hash: %i[any any] })).to eq("hash(any, any)")
        expect(described_class.format_type({ hash: %i[symbol string] })).to eq("hash(symbol, string)")
      end

      it "formats complex hash types" do
        complex_type = { hash: [:string, { array: :integer }] }
        expect(described_class.format_type(complex_type)).to eq("hash(string, array(integer))")
      end
    end

    context "with unknown or malformed types" do
      it "falls back to inspect for unknown types" do
        unknown_type = { unknown: :type }
        expect(described_class.format_type(unknown_type)).to eq(unknown_type.inspect)
      end

      it "formats non-symbol primitive types using inspect" do
        expect(described_class.format_type("string_literal")).to eq('"string_literal"')
        expect(described_class.format_type(123)).to eq("123")
      end
    end
  end
end
