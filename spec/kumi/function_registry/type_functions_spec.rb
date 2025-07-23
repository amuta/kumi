# frozen_string_literal: true

require "spec_helper"
require "support/function_test_helpers"

RSpec.describe Kumi::FunctionRegistry::TypeFunctions do
  describe "hash operations" do
    it_behaves_like "a function with correct metadata", :fetch, -1, [Kumi::Types.hash(:any, :any), :any, :any], :any
    it_behaves_like "a function with correct metadata", :has_key?, 2, [Kumi::Types.hash(:any, :any), :any], :boolean
    it_behaves_like "a function with correct metadata", :keys, 1, [Kumi::Types.hash(:any, :any)], Kumi::Types.array(:any)
    it_behaves_like "a function with correct metadata", :values, 1, [Kumi::Types.hash(:any, :any)], Kumi::Types.array(:any)

    describe "fetch function" do
      it_behaves_like "a working function", :fetch, [{ "a" => 1, "b" => 2 }, "a"], 1
      it_behaves_like "a working function", :fetch, [{ "a" => 1, "b" => 2 }, "c", "default"], "default"

      it "works with 2 arguments (no default)" do
        fn = Kumi::FunctionRegistry.fetch(:fetch)
        hash = { "key" => "value" }
        expect(fn.call(hash, "key")).to eq("value")
        expect(fn.call(hash, "missing")).to be_nil
      end

      it "works with 3 arguments (with default)" do
        fn = Kumi::FunctionRegistry.fetch(:fetch)
        hash = { "key" => "value" }
        expect(fn.call(hash, "key", "default")).to eq("value")
        expect(fn.call(hash, "missing", "default")).to eq("default")
      end

      it "handles different key types" do
        fn = Kumi::FunctionRegistry.fetch(:fetch)
        hash = { "string" => 1, :symbol => 2, 42 => 3 }
        expect(fn.call(hash, "string")).to eq(1)
        expect(fn.call(hash, :symbol)).to eq(2)
        expect(fn.call(hash, 42)).to eq(3)
      end

      it "handles nil values vs missing keys" do
        fn = Kumi::FunctionRegistry.fetch(:fetch)
        hash = { "exists" => nil }
        expect(fn.call(hash, "exists")).to be_nil
        expect(fn.call(hash, "missing")).to be_nil
        expect(fn.call(hash, "exists", "default")).to be_nil # nil value, not missing
        expect(fn.call(hash, "missing", "default")).to eq("default") # missing key
      end

      it "handles complex values" do
        fn = Kumi::FunctionRegistry.fetch(:fetch)
        hash = {
          "array" => [1, 2, 3],
          "hash" => { "nested" => "value" },
          "number" => 42,
          "boolean" => true
        }
        expect(fn.call(hash, "array")).to eq([1, 2, 3])
        expect(fn.call(hash, "hash")).to eq({ "nested" => "value" })
        expect(fn.call(hash, "number")).to eq(42)
        expect(fn.call(hash, "boolean")).to be true
      end
    end

    describe "has_key? function" do
      it_behaves_like "a working function", :has_key?, [{ "a" => 1, "b" => 2 }, "a"], true
      it_behaves_like "a working function", :has_key?, [{ "a" => 1, "b" => 2 }, "c"], false

      it "handles different key types" do
        fn = Kumi::FunctionRegistry.fetch(:has_key?)
        hash = { "string" => 1, :symbol => 2, 42 => 3 }
        expect(fn.call(hash, "string")).to be true
        expect(fn.call(hash, :symbol)).to be true
        expect(fn.call(hash, 42)).to be true
        expect(fn.call(hash, "missing")).to be false
        expect(fn.call(hash, :missing)).to be false
      end

      it "distinguishes between nil values and missing keys" do
        fn = Kumi::FunctionRegistry.fetch(:has_key?)
        hash = { "exists" => nil }
        expect(fn.call(hash, "exists")).to be true # key exists, even with nil value
        expect(fn.call(hash, "missing")).to be false # key doesn't exist
      end

      it "handles empty hashes" do
        fn = Kumi::FunctionRegistry.fetch(:has_key?)
        expect(fn.call({}, "any_key")).to be false
      end
    end

    describe "keys function" do
      it_behaves_like "a working function", :keys, [{ "a" => 1, "b" => 2 }], ["a", "b"]

      it "handles empty hashes" do
        fn = Kumi::FunctionRegistry.fetch(:keys)
        expect(fn.call({})).to eq([])
      end

      it "handles mixed key types" do
        fn = Kumi::FunctionRegistry.fetch(:keys)
        hash = { "string" => 1, :symbol => 2, 42 => 3 }
        keys = fn.call(hash)
        expect(keys).to contain_exactly("string", :symbol, 42)
      end

      it "returns keys in hash iteration order" do
        fn = Kumi::FunctionRegistry.fetch(:keys)
        # Ruby preserves insertion order for hashes
        hash = {}
        hash["first"] = 1
        hash["second"] = 2
        hash["third"] = 3
        expect(fn.call(hash)).to eq(["first", "second", "third"])
      end
    end

    describe "values function" do
      it_behaves_like "a working function", :values, [{ "a" => 1, "b" => 2 }], [1, 2]

      it "handles empty hashes" do
        fn = Kumi::FunctionRegistry.fetch(:values)
        expect(fn.call({})).to eq([])
      end

      it "handles mixed value types" do
        fn = Kumi::FunctionRegistry.fetch(:values)
        hash = { "string" => "value", "number" => 42, "boolean" => true, "nil" => nil }
        values = fn.call(hash)
        expect(values).to contain_exactly("value", 42, true, nil)
      end

      it "handles duplicate values" do
        fn = Kumi::FunctionRegistry.fetch(:values)
        hash = { "a" => 1, "b" => 1, "c" => 2 }
        expect(fn.call(hash)).to eq([1, 1, 2])
      end

      it "returns values in hash iteration order" do
        fn = Kumi::FunctionRegistry.fetch(:values)
        # Ruby preserves insertion order for hashes
        hash = {}
        hash["first"] = "A"
        hash["second"] = "B"
        hash["third"] = "C"
        expect(fn.call(hash)).to eq(["A", "B", "C"])
      end
    end
  end

  describe "array operations" do
    it_behaves_like "a function with correct metadata", :at, 2, [Kumi::Types.array(:any), :integer], :any

    describe "at function" do
      it_behaves_like "a working function", :at, [[10, 20, 30], 1], 20
      it_behaves_like "a working function", :at, [[10, 20, 30], -1], 30

      it "handles positive indices" do
        fn = Kumi::FunctionRegistry.fetch(:at)
        array = ["a", "b", "c", "d"]
        expect(fn.call(array, 0)).to eq("a")
        expect(fn.call(array, 1)).to eq("b")
        expect(fn.call(array, 2)).to eq("c")
        expect(fn.call(array, 3)).to eq("d")
      end

      it "handles negative indices" do
        fn = Kumi::FunctionRegistry.fetch(:at)
        array = ["a", "b", "c", "d"]
        expect(fn.call(array, -1)).to eq("d")
        expect(fn.call(array, -2)).to eq("c")
        expect(fn.call(array, -3)).to eq("b")
        expect(fn.call(array, -4)).to eq("a")
      end

      it "handles out of bounds indices" do
        fn = Kumi::FunctionRegistry.fetch(:at)
        array = ["a", "b", "c"]
        expect(fn.call(array, 10)).to be_nil
        expect(fn.call(array, -10)).to be_nil
      end

      it "handles empty arrays" do
        fn = Kumi::FunctionRegistry.fetch(:at)
        expect(fn.call([], 0)).to be_nil
        expect(fn.call([], -1)).to be_nil
      end

      it "handles single element arrays" do
        fn = Kumi::FunctionRegistry.fetch(:at)
        array = [42]
        expect(fn.call(array, 0)).to eq(42)
        expect(fn.call(array, -1)).to eq(42)
        expect(fn.call(array, 1)).to be_nil
      end

      it "works with strings" do
        fn = Kumi::FunctionRegistry.fetch(:at)
        expect(fn.call("hello", 0)).to eq("h")
        expect(fn.call("hello", 1)).to eq("e")
        expect(fn.call("hello", -1)).to eq("o")
        expect(fn.call("hello", 10)).to be_nil
      end

      it "handles mixed types in arrays" do
        fn = Kumi::FunctionRegistry.fetch(:at)
        array = [1, "string", true, nil, [1, 2, 3]]
        expect(fn.call(array, 0)).to eq(1)
        expect(fn.call(array, 1)).to eq("string")
        expect(fn.call(array, 2)).to be true
        expect(fn.call(array, 3)).to be_nil
        expect(fn.call(array, 4)).to eq([1, 2, 3])
      end
    end
  end

  describe "type function combinations" do
    it "can combine hash and array operations" do
      fetch_fn = Kumi::FunctionRegistry.fetch(:fetch)
      at_fn = Kumi::FunctionRegistry.fetch(:at)
      keys_fn = Kumi::FunctionRegistry.fetch(:keys)

      # Get array from hash, then access element
      data = { "numbers" => [10, 20, 30, 40] }
      numbers = fetch_fn.call(data, "numbers")
      second_number = at_fn.call(numbers, 1)
      expect(second_number).to eq(20)

      # Get keys from hash, then access first key
      first_key = at_fn.call(keys_fn.call(data), 0)
      expect(first_key).to eq("numbers")
    end

    it "demonstrates practical data access patterns" do
      fetch_fn = Kumi::FunctionRegistry.fetch(:fetch)
      at_fn = Kumi::FunctionRegistry.fetch(:at)
      has_key_fn = Kumi::FunctionRegistry.fetch(:has_key?)

      # Nested data structure
      user_data = {
        "profile" => {
          "name" => "John Doe",
          "scores" => [85, 92, 78, 96]
        },
        "settings" => {
          "theme" => "dark",
          "notifications" => true
        }
      }

      # Safe nested access
      if has_key_fn.call(user_data, "profile")
        profile = fetch_fn.call(user_data, "profile")
        if has_key_fn.call(profile, "scores")
          scores = fetch_fn.call(profile, "scores")
          first_score = at_fn.call(scores, 0)
          expect(first_score).to eq(85)
        end
      end

      # Access with defaults
      theme = fetch_fn.call(
        fetch_fn.call(user_data, "settings", {}),
        "theme",
        "light"
      )
      expect(theme).to eq("dark")

      missing_setting = fetch_fn.call(
        fetch_fn.call(user_data, "missing_section", {}),
        "missing_key",
        "default_value"
      )
      expect(missing_setting).to eq("default_value")
    end
  end
end