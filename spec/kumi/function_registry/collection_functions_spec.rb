# frozen_string_literal: true

require "spec_helper"
require "support/function_test_helpers"

RSpec.describe Kumi::Core::FunctionRegistry::CollectionFunctions do
  describe "collection queries" do
    it_behaves_like "a function with correct metadata", :empty?, 1, [Kumi::Core::Types.array(:any)], :boolean
    it_behaves_like "a function with correct metadata", :size, 1, [:any], :integer

    it_behaves_like "a working function", :empty?, [[]], true
    it_behaves_like "a working function", :empty?, [[1, 2, 3]], false
    it_behaves_like "a working function", :size, [[1, 2, 3]], 3

    describe "edge cases" do
      it "handles nested arrays" do
        fn = Kumi::Registry.fetch(:size)
        expect(fn.call([[1, 2], [3, 4], [5]])).to eq(3)

        fn = Kumi::Registry.fetch(:empty?)
        expect(fn.call([[], [], []])).to be false # array contains empty arrays, but isn't empty itself
      end
    end
  end

  describe "element access" do
    it_behaves_like "a function with correct metadata", :first, 1, [Kumi::Core::Types.array(:any)], :any
    it_behaves_like "a function with correct metadata", :last, 1, [Kumi::Core::Types.array(:any)], :any

    it_behaves_like "a working function", :first, [[1, 2, 3]], 1
    it_behaves_like "a working function", :last, [[1, 2, 3]], 3

    describe "edge cases" do
      it "handles single element arrays" do
        fn = Kumi::Registry.fetch(:first)
        expect(fn.call([42])).to eq(42)

        fn = Kumi::Registry.fetch(:last)
        expect(fn.call([42])).to eq(42)
      end

      it "handles empty arrays" do
        fn = Kumi::Registry.fetch(:first)
        expect(fn.call([])).to be_nil

        fn = Kumi::Registry.fetch(:last)
        expect(fn.call([])).to be_nil
      end

      it "handles mixed types" do
        array = [1, "hello", true, nil]

        fn = Kumi::Registry.fetch(:first)
        expect(fn.call(array)).to eq(1)

        fn = Kumi::Registry.fetch(:last)
        expect(fn.call(array)).to be_nil
      end

      it "works with strings" do
        fn = Kumi::Registry.fetch(:first)
        expect(fn.call("hello".chars)).to eq("h")

        fn = Kumi::Registry.fetch(:last)
        expect(fn.call("hello".chars)).to eq("o")
      end
    end
  end

  describe "mathematical operations on collections" do
    it_behaves_like "a function with correct metadata", :sum, 1, [Kumi::Core::Types.array(:float)], :float
    it_behaves_like "a function with correct metadata", :min, 1, [Kumi::Core::Types.array(:float)], :float
    it_behaves_like "a function with correct metadata", :max, 1, [Kumi::Core::Types.array(:float)], :float

    it_behaves_like "a working function", :sum, [[1, 2, 3]], 6
    it_behaves_like "a working function", :min, [[3, 1, 2]], 1
    it_behaves_like "a working function", :max, [[3, 1, 2]], 3

    describe "edge cases" do
      it "handles empty arrays" do
        fn = Kumi::Registry.fetch(:sum)
        expect(fn.call([])).to eq(0)

        fn = Kumi::Registry.fetch(:min)
        expect(fn.call([])).to be_nil

        fn = Kumi::Registry.fetch(:max)
        expect(fn.call([])).to be_nil
      end

      it "handles single element arrays" do
        fn = Kumi::Registry.fetch(:sum)
        expect(fn.call([42])).to eq(42)

        fn = Kumi::Registry.fetch(:min)
        expect(fn.call([42])).to eq(42)

        fn = Kumi::Registry.fetch(:max)
        expect(fn.call([42])).to eq(42)
      end

      it "handles negative numbers" do
        array = [-5, -1, -10, -3]

        fn = Kumi::Registry.fetch(:sum)
        expect(fn.call(array)).to eq(-19)

        fn = Kumi::Registry.fetch(:min)
        expect(fn.call(array)).to eq(-10)

        fn = Kumi::Registry.fetch(:max)
        expect(fn.call(array)).to eq(-1)
      end

      it "handles decimal numbers" do
        array = [1.5, 2.3, 0.7]

        fn = Kumi::Registry.fetch(:sum)
        expect(fn.call(array)).to be_within(0.001).of(4.5)

        fn = Kumi::Registry.fetch(:min)
        expect(fn.call(array)).to eq(0.7)

        fn = Kumi::Registry.fetch(:max)
        expect(fn.call(array)).to eq(2.3)
      end
    end
  end

  describe "collection operations" do
    it_behaves_like "a function with correct metadata", :include?, 2, [Kumi::Core::Types.array(:any), :any], :boolean
    it_behaves_like "a function with correct metadata", :reverse, 1, [Kumi::Core::Types.array(:any)], Kumi::Core::Types.array(:any)
    it_behaves_like "a function with correct metadata", :sort, 1, [Kumi::Core::Types.array(:any)], Kumi::Core::Types.array(:any)
    it_behaves_like "a function with correct metadata", :unique, 1, [Kumi::Core::Types.array(:any)], Kumi::Core::Types.array(:any)

    it_behaves_like "a working function", :include?, [[1, 2, 3], 2], true
    it_behaves_like "a working function", :include?, [[1, 2, 3], 4], false
    it_behaves_like "a working function", :reverse, [[1, 2, 3]], [3, 2, 1]
    it_behaves_like "a working function", :sort, [[3, 1, 2]], [1, 2, 3]
    it_behaves_like "a working function", :unique, [[1, 2, 2, 3]], [1, 2, 3]

    describe "include? edge cases" do
      it "handles different types" do
        fn = Kumi::Registry.fetch(:include?)
        expect(fn.call([1, "hello", true], "hello")).to be true
        expect(fn.call([1, "hello", true], "world")).to be false
        expect(fn.call([1, "hello", true], 1)).to be true
        expect(fn.call([1, "hello", true], true)).to be true
      end

      it "handles nil values" do
        fn = Kumi::Registry.fetch(:include?)
        expect(fn.call([1, nil, 3], nil)).to be true
        expect(fn.call([1, 2, 3], nil)).to be false
      end

      it "works with strings (string contains substring)" do
        fn = Kumi::Registry.fetch(:include?)
        expect(fn.call("hello world", "world")).to be true
        expect(fn.call("hello world", "xyz")).to be false
      end
    end

    describe "reverse edge cases" do
      it "handles empty arrays" do
        fn = Kumi::Registry.fetch(:reverse)
        expect(fn.call([])).to eq([])
      end

      it "handles single element arrays" do
        fn = Kumi::Registry.fetch(:reverse)
        expect(fn.call([42])).to eq([42])
      end

      it "preserves original array" do
        fn = Kumi::Registry.fetch(:reverse)
        original = [1, 2, 3]
        result = fn.call(original)
        expect(result).to eq([3, 2, 1])
        expect(original).to eq([1, 2, 3]) # original unchanged
      end

      it "works with strings" do
        fn = Kumi::Registry.fetch(:reverse)
        expect(fn.call("hello")).to eq("olleh")
      end
    end

    describe "sort edge cases" do
      it "handles empty arrays" do
        fn = Kumi::Registry.fetch(:sort)
        expect(fn.call([])).to eq([])
      end

      it "handles single element arrays" do
        fn = Kumi::Registry.fetch(:sort)
        expect(fn.call([42])).to eq([42])
      end

      it "handles strings" do
        fn = Kumi::Registry.fetch(:sort)
        expect(fn.call(%w[zebra apple banana])).to eq(%w[apple banana zebra])
      end

      it "handles mixed comparable types" do
        fn = Kumi::Registry.fetch(:sort)
        expect(fn.call([3, 1, 4, 1, 5])).to eq([1, 1, 3, 4, 5])
      end

      it "works with string characters" do
        fn = Kumi::Registry.fetch(:sort)
        expect(fn.call("hello".chars).join).to eq("ehllo")
      end
    end

    describe "unique edge cases" do
      it "handles empty arrays" do
        fn = Kumi::Registry.fetch(:unique)
        expect(fn.call([])).to eq([])
      end

      it "handles arrays with no duplicates" do
        fn = Kumi::Registry.fetch(:unique)
        expect(fn.call([1, 2, 3])).to eq([1, 2, 3])
      end

      it "handles arrays with all duplicates" do
        fn = Kumi::Registry.fetch(:unique)
        expect(fn.call([5, 5, 5, 5])).to eq([5])
      end

      it "preserves order of first occurrence" do
        fn = Kumi::Registry.fetch(:unique)
        expect(fn.call([3, 1, 2, 1, 3, 2])).to eq([3, 1, 2])
      end

      it "handles mixed types" do
        fn = Kumi::Registry.fetch(:unique)
        expect(fn.call([1, "hello", 1, "world", "hello"])).to eq([1, "hello", "world"])
      end

      it "works with string characters" do
        fn = Kumi::Registry.fetch(:unique)
        expect(fn.call("hello".chars).join).to eq("helo")
      end
    end
  end
end
