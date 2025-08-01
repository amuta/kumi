# frozen_string_literal: true

require "spec_helper"
require "support/function_test_helpers"

RSpec.describe Kumi::Core::FunctionRegistry::StringFunctions do
  describe "string transformations" do
    it_behaves_like "a function with correct metadata", :upcase, 1, [:string], :string
    it_behaves_like "a function with correct metadata", :downcase, 1, [:string], :string
    it_behaves_like "a function with correct metadata", :capitalize, 1, [:string], :string
    it_behaves_like "a function with correct metadata", :strip, 1, [:string], :string

    it_behaves_like "a working function", :upcase, ["hello"], "HELLO"
    it_behaves_like "a working function", :downcase, ["HELLO"], "hello"
    it_behaves_like "a working function", :capitalize, ["hello world"], "Hello world"
    it_behaves_like "a working function", :strip, [" hello "], "hello"

    describe "edge cases" do
      it_behaves_like "a working function", :upcase, [""], ""
      it_behaves_like "a working function", :downcase, [""], ""
      it_behaves_like "a working function", :capitalize, [""], ""
      it_behaves_like "a working function", :strip, [""], ""
      it_behaves_like "a working function", :strip, ["   "], ""

      it "handles mixed case strings" do
        fn = Kumi::Registry.fetch(:upcase)
        expect(fn.call("HeLLo WoRLd")).to eq("HELLO WORLD")

        fn = Kumi::Registry.fetch(:downcase)
        expect(fn.call("HeLLo WoRLd")).to eq("hello world")
      end

      it "handles special characters" do
        fn = Kumi::Registry.fetch(:upcase)
        expect(fn.call("hello-world_123")).to eq("HELLO-WORLD_123")

        fn = Kumi::Registry.fetch(:strip)
        expect(fn.call("\t\n hello \r\n\t")).to eq("hello")
      end

      it "handles unicode characters" do
        fn = Kumi::Registry.fetch(:upcase)
        expect(fn.call("héllo")).to eq("HÉLLO")

        fn = Kumi::Registry.fetch(:downcase)
        expect(fn.call("HÉLLO")).to eq("héllo")
      end
    end
  end

  describe "string length" do
    # NOTE: collection length overrides string length in the registry
    it_behaves_like "a function with correct metadata", :string_length, 1, [:string], :integer
    it_behaves_like "a function with correct metadata", :length, 1, [Kumi::Core::Types.array(:any)], :integer

    it_behaves_like "a working function", :string_length, ["hello"], 5
    it_behaves_like "a working function", :string_length, [""], 0

    describe "edge cases" do
      it "handles unicode characters correctly" do
        fn = Kumi::Registry.fetch(:string_length)
        expect(fn.call("café")).to eq(4)
        expect(fn.call("🌟⭐")).to eq(2)
      end

      it "handles whitespace" do
        fn = Kumi::Registry.fetch(:string_length)
        expect(fn.call("   ")).to eq(3)
        expect(fn.call("\t\n")).to eq(2)
      end
    end
  end

  describe "string queries" do
    # NOTE: collection include? overrides string include? in the registry
    it_behaves_like "a function with correct metadata", :include?, 2, [Kumi::Core::Types.array(:any), :any], :boolean
    it_behaves_like "a function with correct metadata", :start_with?, 2, %i[string string], :boolean
    it_behaves_like "a function with correct metadata", :end_with?, 2, %i[string string], :boolean

    describe "start_with? function" do
      it_behaves_like "a working function", :start_with?, ["hello world", "hello"], true
      it_behaves_like "a working function", :start_with?, ["hello world", "world"], false
      it_behaves_like "a working function", :start_with?, ["hello world", ""], true

      it "handles case sensitivity" do
        fn = Kumi::Registry.fetch(:start_with?)
        expect(fn.call("Hello World", "hello")).to be false
        expect(fn.call("Hello World", "Hello")).to be true
      end

      it "handles edge cases" do
        fn = Kumi::Registry.fetch(:start_with?)
        expect(fn.call("", "")).to be true
        expect(fn.call("", "hello")).to be false
        expect(fn.call("hello", "hello world")).to be false
      end
    end

    describe "end_with? function" do
      it_behaves_like "a working function", :end_with?, ["hello world", "world"], true
      it_behaves_like "a working function", :end_with?, ["hello world", "hello"], false
      it_behaves_like "a working function", :end_with?, ["hello world", ""], true

      it "handles case sensitivity" do
        fn = Kumi::Registry.fetch(:end_with?)
        expect(fn.call("Hello World", "world")).to be false
        expect(fn.call("Hello World", "World")).to be true
      end

      it "handles edge cases" do
        fn = Kumi::Registry.fetch(:end_with?)
        expect(fn.call("", "")).to be true
        expect(fn.call("", "hello")).to be false
        expect(fn.call("world", "hello world")).to be false
      end
    end
  end

  describe "string building" do
    it_behaves_like "a function with correct metadata", :concat, -1, [:string], :string

    it_behaves_like "a working function", :concat, ["hello", " ", "world"], "hello world"
    it_behaves_like "a working function", :concat, ["a"], "a"
    it_behaves_like "a working function", :concat, [], ""

    describe "concat edge cases" do
      it "handles multiple strings" do
        fn = Kumi::Registry.fetch(:concat)
        expect(fn.call("a", "b", "c", "d", "e")).to eq("abcde")
      end

      it "handles empty strings" do
        fn = Kumi::Registry.fetch(:concat)
        expect(fn.call("", "hello", "", "world", "")).to eq("helloworld")
      end

      it "handles numbers and other types" do
        fn = Kumi::Registry.fetch(:concat)
        expect(fn.call("Number: ", 42, " End")).to eq("Number: 42 End")
      end
    end
  end

  describe "string include? behavior with collection override" do
    # Since collection include? overrides string include?, test the actual behavior
    it "works with arrays (collection function)" do
      fn = Kumi::Registry.fetch(:include?)
      expect(fn.call(%w[hello world], "hello")).to be true
      expect(fn.call(%w[hello world], "xyz")).to be false
    end

    it "also works with strings as arrays of characters" do
      fn = Kumi::Registry.fetch(:include?)
      # String acts like a collection in this context
      expect(fn.call("hello world", "world")).to be true
      expect(fn.call("hello world", "xyz")).to be false
    end
  end

  describe "string length behavior with collection override" do
    # Since collection length overrides string length, test the actual behavior
    it "works with arrays (collection function)" do
      fn = Kumi::Registry.fetch(:length)
      expect(fn.call([1, 2, 3])).to eq(3)
      expect(fn.call([])).to eq(0)
    end

    it "also works with strings" do
      fn = Kumi::Registry.fetch(:length)
      expect(fn.call("hello")).to eq(5)
      expect(fn.call("")).to eq(0)
    end
  end
end
