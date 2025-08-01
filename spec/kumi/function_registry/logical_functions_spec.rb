# frozen_string_literal: true

require "spec_helper"
require "support/function_test_helpers"

RSpec.describe Kumi::Core::FunctionRegistry::LogicalFunctions do
  describe "basic logical operations" do
    it_behaves_like "a function with correct metadata", :and, -1, [:boolean], :boolean
    it_behaves_like "a function with correct metadata", :or, -1, [:boolean], :boolean
    it_behaves_like "a function with correct metadata", :not, 1, [:boolean], :boolean

    describe "and function" do
      it_behaves_like "a working function", :and, [true, true], true
      it_behaves_like "a working function", :and, [true, false], false
      it_behaves_like "a working function", :and, [true, true, true], true
      it_behaves_like "a working function", :and, [true, true, false], false

      it "handles single argument" do
        fn = Kumi::Registry.fetch(:and)
        expect(fn.call(true)).to be true
        expect(fn.call(false)).to be false
      end

      it "handles many arguments" do
        fn = Kumi::Registry.fetch(:and)
        expect(fn.call(true, true, true, true, true)).to be true
        expect(fn.call(true, true, true, false, true)).to be false
      end

      it "handles empty arguments" do
        fn = Kumi::Registry.fetch(:and)
        expect(fn.call).to be true # all? on empty array returns true
      end
    end

    describe "or function" do
      it_behaves_like "a working function", :or, [true, false], true
      it_behaves_like "a working function", :or, [false, false], false
      it_behaves_like "a working function", :or, [false, false, true], true

      it "handles single argument" do
        fn = Kumi::Registry.fetch(:or)
        expect(fn.call(true)).to be true
        expect(fn.call(false)).to be false
      end

      it "handles many arguments" do
        fn = Kumi::Registry.fetch(:or)
        expect(fn.call(false, false, false, false, false)).to be false
        expect(fn.call(false, false, false, true, false)).to be true
      end

      it "handles empty arguments" do
        fn = Kumi::Registry.fetch(:or)
        expect(fn.call).to be false # any? on empty array returns false
      end
    end

    describe "not function" do
      it_behaves_like "a working function", :not, [true], false
      it_behaves_like "a working function", :not, [false], true
    end
  end

  describe "collection logical operations" do
    it_behaves_like "a function with correct metadata", :all?, 1, [Kumi::Core::Types.array(:any)], :boolean
    it_behaves_like "a function with correct metadata", :any?, 1, [Kumi::Core::Types.array(:any)], :boolean
    it_behaves_like "a function with correct metadata", :none?, 1, [Kumi::Core::Types.array(:any)], :boolean

    describe "all? function" do
      it_behaves_like "a working function", :all?, [[true, true, true]], true
      it_behaves_like "a working function", :all?, [[true, false, true]], false

      it "handles truthy/falsy values" do
        fn = Kumi::Registry.fetch(:all?)
        expect(fn.call([1, 2, 3])).to be true # all truthy
        expect(fn.call([true, false, true])).to be false # false is falsy
        expect(fn.call([1, nil, 3])).to be false # nil is falsy
        expect(fn.call([1, "", 3])).to be true # empty string is truthy
      end

      it "handles empty arrays" do
        fn = Kumi::Registry.fetch(:all?)
        expect(fn.call([])).to be true
      end
    end

    describe "any? function" do
      it_behaves_like "a working function", :any?, [[false, false, true]], true
      it_behaves_like "a working function", :any?, [[false, false, false]], false

      it "handles truthy/falsy values" do
        fn = Kumi::Registry.fetch(:any?)
        expect(fn.call([nil, false])).to be false # all falsy (0 is truthy in Ruby)
        expect(fn.call([nil, false, 1])).to be true # one truthy
        expect(fn.call([nil, "", false])).to be true # empty string is truthy
      end

      it "handles empty arrays" do
        fn = Kumi::Registry.fetch(:any?)
        expect(fn.call([])).to be false
      end
    end

    describe "none? function" do
      it_behaves_like "a working function", :none?, [[false, false, false]], true
      it_behaves_like "a working function", :none?, [[false, true, false]], false

      it "handles truthy/falsy values" do
        fn = Kumi::Registry.fetch(:none?)
        expect(fn.call([nil, false])).to be true # all falsy (0 is truthy in Ruby)
        expect(fn.call([nil, false, 1])).to be false # one truthy
        expect(fn.call([nil, "", false])).to be false # empty string is truthy
      end

      it "handles empty arrays" do
        fn = Kumi::Registry.fetch(:none?)
        expect(fn.call([])).to be true
      end
    end
  end

  describe "logical combinations" do
    it "can combine logical operations" do
      and_fn = Kumi::Registry.fetch(:and)
      or_fn = Kumi::Registry.fetch(:or)
      not_fn = Kumi::Registry.fetch(:not)

      # (true AND false) OR (NOT false) = false OR true = true
      result1 = and_fn.call(true, false)
      result2 = not_fn.call(false)
      final_result = or_fn.call(result1, result2)
      expect(final_result).to be true
    end

    it "demonstrates De Morgan's laws" do
      and_fn = Kumi::Registry.fetch(:and)
      or_fn = Kumi::Registry.fetch(:or)
      not_fn = Kumi::Registry.fetch(:not)

      # NOT (A AND B) = (NOT A) OR (NOT B)
      a = true
      b = false
      left_side = not_fn.call(and_fn.call(a, b))
      right_side = or_fn.call(not_fn.call(a), not_fn.call(b))
      expect(left_side).to eq(right_side)

      # NOT (A OR B) = (NOT A) AND (NOT B)
      left_side = not_fn.call(or_fn.call(a, b))
      right_side = and_fn.call(not_fn.call(a), not_fn.call(b))
      expect(left_side).to eq(right_side)
    end
  end
end
