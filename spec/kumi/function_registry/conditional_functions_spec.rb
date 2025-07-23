# frozen_string_literal: true

require "spec_helper"
require "support/function_test_helpers"

RSpec.describe Kumi::FunctionRegistry::ConditionalFunctions do
  describe "conditional function" do
    it_behaves_like "a function with correct metadata", :conditional, 3, %i[boolean any any], :any

    it_behaves_like "a working function", :conditional, [true, "yes", "no"], "yes"
    it_behaves_like "a working function", :conditional, [false, "yes", "no"], "no"

    describe "edge cases" do
      it "handles different return types" do
        fn = Kumi::FunctionRegistry.fetch(:conditional)
        expect(fn.call(true, 42, "string")).to eq(42)
        expect(fn.call(false, 42, "string")).to eq("string")
      end

      it "handles nil values" do
        fn = Kumi::FunctionRegistry.fetch(:conditional)
        expect(fn.call(true, nil, "fallback")).to be_nil
        expect(fn.call(false, "value", nil)).to be_nil
      end

      it "handles complex objects" do
        fn = Kumi::FunctionRegistry.fetch(:conditional)
        array1 = [1, 2, 3]
        array2 = [4, 5, 6]
        expect(fn.call(true, array1, array2)).to eq(array1)
        expect(fn.call(false, array1, array2)).to eq(array2)
      end

      it "evaluates both branches (not lazy)" do
        fn = Kumi::FunctionRegistry.fetch(:conditional)
        # Both values are already evaluated when passed to the function
        result = fn.call(true, "first", "second")
        expect(result).to eq("first")
      end
    end
  end

  describe "if function" do
    it_behaves_like "a function with correct metadata", :if, -1, %i[boolean any any], :any

    it_behaves_like "a working function", :if, [true, "yes", "no"], "yes"
    it_behaves_like "a working function", :if, [false, "yes", "no"], "no"
    it_behaves_like "a working function", :if, [true, "yes"], "yes"
    it_behaves_like "a working function", :if, [false, "yes"], nil

    describe "variable arity" do
      it "works with 2 arguments (condition and true value)" do
        fn = Kumi::FunctionRegistry.fetch(:if)
        expect(fn.call(true, "value")).to eq("value")
        expect(fn.call(false, "value")).to be_nil
      end

      it "works with 3 arguments (condition, true value, false value)" do
        fn = Kumi::FunctionRegistry.fetch(:if)
        expect(fn.call(true, "true_val", "false_val")).to eq("true_val")
        expect(fn.call(false, "true_val", "false_val")).to eq("false_val")
      end

      it "handles explicit nil as false value" do
        fn = Kumi::FunctionRegistry.fetch(:if)
        expect(fn.call(true, "value", nil)).to eq("value")
        expect(fn.call(false, "value", nil)).to be_nil
      end
    end

    describe "edge cases" do
      it "handles different return types" do
        fn = Kumi::FunctionRegistry.fetch(:if)
        expect(fn.call(true, 123)).to eq(123)
        expect(fn.call(false, 123)).to be_nil
        expect(fn.call(true, [], {})).to eq([])
        expect(fn.call(false, [], {})).to eq({})
      end

      it "handles falsy conditions properly" do
        fn = Kumi::FunctionRegistry.fetch(:if)
        # Only false and nil are falsy in Ruby boolean context for this function
        expect(fn.call(false, "value", "fallback")).to eq("fallback")
        # NOTE: The function expects actual boolean values based on signature
      end
    end
  end

  describe "coalesce function" do
    it_behaves_like "a function with correct metadata", :coalesce, -1, [:any], :any

    it_behaves_like "a working function", :coalesce, [nil, nil, "found"], "found"
    it_behaves_like "a working function", :coalesce, %w[first second], "first"
    it_behaves_like "a working function", :coalesce, [nil], nil

    describe "variable arity" do
      it "works with single argument" do
        fn = Kumi::FunctionRegistry.fetch(:coalesce)
        expect(fn.call("value")).to eq("value")
        expect(fn.call(nil)).to be_nil
      end

      it "works with many arguments" do
        fn = Kumi::FunctionRegistry.fetch(:coalesce)
        expect(fn.call(nil, nil, nil, nil, "found")).to eq("found")
        expect(fn.call(nil, nil, nil, nil, nil)).to be_nil
      end

      it "returns first non-nil value" do
        fn = Kumi::FunctionRegistry.fetch(:coalesce)
        expect(fn.call(nil, "first", "second", "third")).to eq("first")
        expect(fn.call(nil, nil, "second", "third")).to eq("second")
      end

      it "handles empty arguments" do
        fn = Kumi::FunctionRegistry.fetch(:coalesce)
        expect(fn.call).to be_nil
      end
    end

    describe "edge cases" do
      it "distinguishes nil from other falsy values" do
        fn = Kumi::FunctionRegistry.fetch(:coalesce)
        expect(fn.call(nil, false)).to be(false) # false is not nil
        expect(fn.call(nil, 0)).to eq(0) # 0 is not nil
        expect(fn.call(nil, "")).to eq("") # empty string is not nil
        expect(fn.call(nil, [])).to eq([]) # empty array is not nil
      end

      it "handles different types" do
        fn = Kumi::FunctionRegistry.fetch(:coalesce)
        expect(fn.call(nil, 42)).to eq(42)
        expect(fn.call(nil, true)).to be true
        expect(fn.call(nil, [1, 2, 3])).to eq([1, 2, 3])
        expect(fn.call(nil, { "key" => "value" })).to eq({ "key" => "value" })
      end

      it "short-circuits on first non-nil value" do
        fn = Kumi::FunctionRegistry.fetch(:coalesce)
        # This behavior would be hard to test without side effects,
        # but we can verify it returns the first non-nil value
        expect(fn.call(nil, "first", "second")).to eq("first")
      end
    end
  end

  describe "conditional combinations" do
    it "can chain conditional operations" do
      conditional_fn = Kumi::FunctionRegistry.fetch(:conditional)
      if_fn = Kumi::FunctionRegistry.fetch(:if)
      coalesce_fn = Kumi::FunctionRegistry.fetch(:coalesce)

      # Example: nested conditionals
      inner_result = conditional_fn.call(false, "inner_true", "inner_false")
      outer_result = if_fn.call(true, inner_result, "outer_false")
      expect(outer_result).to eq("inner_false")

      # Example: coalesce with conditional
      conditional_result = conditional_fn.call(false, "value", nil)
      coalesced = coalesce_fn.call(conditional_result, "default")
      expect(coalesced).to eq("default")
    end

    it "demonstrates practical usage patterns" do
      conditional_fn = Kumi::FunctionRegistry.fetch(:conditional)
      coalesce_fn = Kumi::FunctionRegistry.fetch(:coalesce)

      # Pattern: provide default for conditional that might return nil
      user_preference = nil
      system_default = "default_theme"

      theme = coalesce_fn.call(
        conditional_fn.call(!user_preference.nil?, user_preference, nil),
        system_default
      )
      expect(theme).to eq("default_theme")

      # Pattern: multiple fallbacks
      primary = nil
      secondary = nil
      tertiary = "fallback"

      result = coalesce_fn.call(primary, secondary, tertiary)
      expect(result).to eq("fallback")
    end
  end
end
