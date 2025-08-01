# frozen_string_literal: true

require "spec_helper"
require "support/function_test_helpers"

RSpec.describe Kumi::Core::FunctionRegistry::ComparisonFunctions do
  describe "comparison functions" do
    it_behaves_like "a function with correct metadata", :==, 2, %i[any any], :boolean
    it_behaves_like "a function with correct metadata", :!=, 2, %i[any any], :boolean
    it_behaves_like "a function with correct metadata", :>, 2, %i[float float], :boolean
    it_behaves_like "a function with correct metadata", :<, 2, %i[float float], :boolean
    it_behaves_like "a function with correct metadata", :>=, 2, %i[float float], :boolean
    it_behaves_like "a function with correct metadata", :<=, 2, %i[float float], :boolean
    it_behaves_like "a function with correct metadata", :between?, 3, %i[float float float], :boolean

    it_behaves_like "a working function", :==, [5, 5], true
    it_behaves_like "a working function", :==, [5, 6], false
    it_behaves_like "a working function", :!=, [5, 6], true
    it_behaves_like "a working function", :!=, [5, 5], false
    it_behaves_like "a working function", :>, [6, 5], true
    it_behaves_like "a working function", :>, [5, 6], false
    it_behaves_like "a working function", :<, [5, 6], true
    it_behaves_like "a working function", :<, [6, 5], false
    it_behaves_like "a working function", :>=, [6, 5], true
    it_behaves_like "a working function", :>=, [5, 5], true
    it_behaves_like "a working function", :>=, [4, 5], false
    it_behaves_like "a working function", :<=, [5, 6], true
    it_behaves_like "a working function", :<=, [5, 5], true
    it_behaves_like "a working function", :<=, [6, 5], false
    it_behaves_like "a working function", :between?, [5, 1, 10], true
    it_behaves_like "a working function", :between?, [15, 1, 10], false

    describe "operator identification" do
      it "identifies core operators correctly" do
        expect(Kumi::Registry.operator?(:==)).to be true
        expect(Kumi::Registry.operator?(:add)).to be false
        expect(Kumi::Registry.operator?("not_a_symbol")).to be false
      end
    end

    describe "string comparisons" do
      it_behaves_like "a working function", :==, %w[hello hello], true
      it_behaves_like "a working function", :==, %w[hello world], false
      it_behaves_like "a working function", :!=, %w[hello world], true
      it_behaves_like "a working function", :!=, %w[hello hello], false
    end

    describe "boolean comparisons" do
      it_behaves_like "a working function", :==, [true, true], true
      it_behaves_like "a working function", :==, [true, false], false
      it_behaves_like "a working function", :!=, [true, false], true
      it_behaves_like "a working function", :!=, [false, false], false
    end

    describe "edge cases" do
      it_behaves_like "a working function", :between?, [5, 5, 5], true
      it_behaves_like "a working function", :between?, [0, 1, 10], false
      it_behaves_like "a working function", :between?, [10, 1, 10], true
    end
  end
end
