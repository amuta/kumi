# frozen_string_literal: true

require "spec_helper"
require "support/function_test_helpers"

RSpec.describe Kumi::Core::FunctionRegistry::MathFunctions do
  describe "basic arithmetic" do
    it_behaves_like "a function with correct metadata", :add, 2, %i[float float], :float
    it_behaves_like "a function with correct metadata", :subtract, 2, %i[float float], :float
    it_behaves_like "a function with correct metadata", :multiply, 2, %i[float float], :float
    it_behaves_like "a function with correct metadata", :divide, 2, %i[float float], :float
    it_behaves_like "a function with correct metadata", :modulo, 2, %i[float float], :float
    it_behaves_like "a function with correct metadata", :power, 2, %i[float float], :float

    it_behaves_like "a working function", :add, [5, 3], 8
    it_behaves_like "a working function", :subtract, [5, 3], 2
    it_behaves_like "a working function", :multiply, [5, 3], 15
    it_behaves_like "a working function", :divide, [15, 3], 5
    it_behaves_like "a working function", :modulo, [7, 3], 1
    it_behaves_like "a working function", :power, [2, 3], 8

    describe "edge cases" do
      it_behaves_like "a working function", :add, [0, 0], 0
      it_behaves_like "a working function", :subtract, [0, 0], 0
      it_behaves_like "a working function", :multiply, [0, 5], 0
      it_behaves_like "a working function", :divide, [0, 5], 0
      it_behaves_like "a working function", :power, [2, 0], 1
      it_behaves_like "a working function", :power, [0, 2], 0

      it "handles negative numbers" do
        fn = Kumi::Core::FunctionRegistry.fetch(:add)
        expect(fn.call(-5, 3)).to eq(-2)
        expect(fn.call(-5, -3)).to eq(-8)
      end

      it "handles decimal numbers" do
        fn = Kumi::Core::FunctionRegistry.fetch(:add)
        expect(fn.call(5.5, 2.3)).to be_within(0.001).of(7.8)

        fn = Kumi::Core::FunctionRegistry.fetch(:divide)
        expect(fn.call(7.0, 2.0)).to eq(3.5)
      end
    end
  end

  describe "unary operations" do
    it_behaves_like "a function with correct metadata", :abs, 1, [:float], :float
    it_behaves_like "a function with correct metadata", :floor, 1, [:float], :integer
    it_behaves_like "a function with correct metadata", :ceil, 1, [:float], :integer

    it_behaves_like "a working function", :abs, [-5], 5
    it_behaves_like "a working function", :abs, [5], 5
    it_behaves_like "a working function", :floor, [5.7], 5
    it_behaves_like "a working function", :ceil, [5.3], 6

    describe "edge cases" do
      it_behaves_like "a working function", :abs, [0], 0
      it_behaves_like "a working function", :floor, [5.0], 5
      it_behaves_like "a working function", :ceil, [5.0], 5
      it_behaves_like "a working function", :floor, [-5.7], -6
      it_behaves_like "a working function", :ceil, [-5.3], -5
    end
  end

  describe "rounding and clamping" do
    it_behaves_like "a function with correct metadata", :round, -1, [:float], :float
    it_behaves_like "a function with correct metadata", :clamp, 3, %i[float float float], :float

    it_behaves_like "a working function", :round, [5.67], 6
    it_behaves_like "a working function", :round, [5.678, 2], 5.68
    it_behaves_like "a working function", :clamp, [5, 1, 10], 5
    it_behaves_like "a working function", :clamp, [-5, 1, 10], 1
    it_behaves_like "a working function", :clamp, [15, 1, 10], 10

    describe "round with different precisions" do
      it "rounds to different decimal places" do
        fn = Kumi::Core::FunctionRegistry.fetch(:round)
        expect(fn.call(3.14159, 0)).to eq(3)
        expect(fn.call(3.14159, 1)).to eq(3.1)
        expect(fn.call(3.14159, 2)).to eq(3.14)
        expect(fn.call(3.14159, 3)).to eq(3.142)
      end

      it "handles negative precision" do
        fn = Kumi::Core::FunctionRegistry.fetch(:round)
        expect(fn.call(1234.56, -1)).to eq(1230.0)
        expect(fn.call(1234.56, -2)).to eq(1200.0)
      end
    end

    describe "clamp edge cases" do
      it_behaves_like "a working function", :clamp, [5, 5, 5], 5
      it_behaves_like "a working function", :clamp, [0, -10, 10], 0
    end
  end

  describe "piecewise_sum function" do
    it_behaves_like "a function with correct metadata", :piecewise_sum, 3,
                    [:float, Kumi::Core::Types.array(:float), Kumi::Core::Types.array(:float)], Kumi::Core::Types.array(:float)

    it "calculates piecewise sum correctly" do
      fn = Kumi::Core::FunctionRegistry.fetch(:piecewise_sum)

      # Basic tiered calculation: 25k * 0.1 + 25k * 0.2 = 2.5k + 5k = 7.5k
      result = fn.call(50_000, [25_000, 50_000, 100_000], [0.1, 0.2, 0.3])
      expect(result[0]).to eq(7_500.0) # 25k * 0.1 + 25k * 0.2
      expect(result[1]).to eq(0.2) # marginal rate at 50k

      # Value exceeding all breaks: 25k*0.1 + 25k*0.2 + 50k*0.3 = 2.5k + 5k + 15k = 22.5k
      result = fn.call(150_000, [25_000, 50_000, 100_000], [0.1, 0.2, 0.3])
      expect(result[0]).to eq(22_500.0) # 25k*0.1 + 25k*0.2 + 50k*0.3
      expect(result[1]).to eq(0.3) # marginal rate above 100k
    end

    it "handles edge cases" do
      fn = Kumi::Core::FunctionRegistry.fetch(:piecewise_sum)

      # Value below first break
      result = fn.call(10_000, [25_000, 50_000], [0.1, 0.2])
      expect(result[0]).to eq(1_000.0) # 10k * 0.1
      expect(result[1]).to eq(0.1) # marginal rate in first tier

      # Value exactly at break
      result = fn.call(25_000, [25_000, 50_000], [0.1, 0.2])
      expect(result[0]).to eq(2_500.0) # 25k * 0.1
      expect(result[1]).to eq(0.1) # marginal rate at first break

      # Single tier
      result = fn.call(10_000, [50_000], [0.15])
      expect(result[0]).to eq(1_500.0) # 10k * 0.15
      expect(result[1]).to eq(0.15)
    end

    it "raises error for mismatched array sizes" do
      fn = Kumi::Core::FunctionRegistry.fetch(:piecewise_sum)
      expect do
        fn.call(50_000, [25_000, 50_000], [0.1, 0.2, 0.3])
      end.to raise_error(ArgumentError, "breaks & rates size mismatch")
    end

    it "handles empty arrays" do
      fn = Kumi::Core::FunctionRegistry.fetch(:piecewise_sum)
      expect do
        fn.call(50_000, [], [])
      end.not_to raise_error

      result = fn.call(50_000, [], [])
      expect(result).to eq([0.0, nil])
    end
  end
end
