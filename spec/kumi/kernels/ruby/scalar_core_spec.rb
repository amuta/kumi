# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Kernels::Ruby::ScalarCore do
  describe ".kumi_add" do
    it "adds two integers" do
      expect(described_class.kumi_add(5, 3)).to eq(8)
    end

    it "adds two floats" do
      expect(described_class.kumi_add(2.5, 1.5)).to eq(4.0)
    end

    it "adds integer and float" do
      expect(described_class.kumi_add(5, 2.5)).to eq(7.5)
    end

    it "handles negative numbers" do
      expect(described_class.kumi_add(-3, 7)).to eq(4)
      expect(described_class.kumi_add(5, -2)).to eq(3)
      expect(described_class.kumi_add(-4, -6)).to eq(-10)
    end

    it "handles zero" do
      expect(described_class.kumi_add(0, 5)).to eq(5)
      expect(described_class.kumi_add(7, 0)).to eq(7)
      expect(described_class.kumi_add(0, 0)).to eq(0)
    end
  end

  describe ".kumi_sub" do
    it "subtracts two integers" do
      expect(described_class.kumi_sub(8, 3)).to eq(5)
    end

    it "subtracts two floats" do
      expect(described_class.kumi_sub(5.5, 2.5)).to eq(3.0)
    end

    it "handles negative results" do
      expect(described_class.kumi_sub(3, 8)).to eq(-5)
    end

    it "handles zero" do
      expect(described_class.kumi_sub(5, 0)).to eq(5)
      expect(described_class.kumi_sub(0, 5)).to eq(-5)
    end
  end

  describe ".kumi_mul" do
    it "multiplies two integers" do
      expect(described_class.kumi_mul(4, 3)).to eq(12)
    end

    it "multiplies two floats" do
      expect(described_class.kumi_mul(2.5, 4.0)).to eq(10.0)
    end

    it "handles negative numbers" do
      expect(described_class.kumi_mul(-3, 4)).to eq(-12)
      expect(described_class.kumi_mul(5, -2)).to eq(-10)
      expect(described_class.kumi_mul(-3, -4)).to eq(12)
    end

    it "handles zero" do
      expect(described_class.kumi_mul(0, 5)).to eq(0)
      expect(described_class.kumi_mul(7, 0)).to eq(0)
    end

    it "handles one" do
      expect(described_class.kumi_mul(1, 5)).to eq(5)
      expect(described_class.kumi_mul(7, 1)).to eq(7)
    end
  end

  describe ".kumi_div" do
    it "divides two integers returning float" do
      expect(described_class.kumi_div(8, 2)).to eq(4.0)
      expect(described_class.kumi_div(7, 2)).to eq(3.5)
    end

    it "divides two floats" do
      expect(described_class.kumi_div(10.0, 2.5)).to eq(4.0)
    end

    it "handles negative numbers" do
      expect(described_class.kumi_div(-8, 2)).to eq(-4.0)
      expect(described_class.kumi_div(8, -2)).to eq(-4.0)
      expect(described_class.kumi_div(-8, -2)).to eq(4.0)
    end

    it "handles division by one" do
      expect(described_class.kumi_div(5, 1)).to eq(5.0)
    end
  end

  describe ".kumi_mod" do
    it "computes modulo of two integers" do
      expect(described_class.kumi_mod(8, 3)).to eq(2)
      expect(described_class.kumi_mod(10, 5)).to eq(0)
    end

    it "handles negative numbers" do
      expect(described_class.kumi_mod(-7, 3)).to eq(2)
      expect(described_class.kumi_mod(7, -3)).to eq(-2)
      expect(described_class.kumi_mod(-7, -3)).to eq(-1)
    end

    it "handles modulo by one" do
      expect(described_class.kumi_mod(5, 1)).to eq(0)
      expect(described_class.kumi_mod(0, 1)).to eq(0)
    end
  end

  describe ".kumi_pow" do
    it "computes power of two integers" do
      expect(described_class.kumi_pow(2, 3)).to eq(8)
      expect(described_class.kumi_pow(5, 2)).to eq(25)
    end

    it "handles power of zero and one" do
      expect(described_class.kumi_pow(5, 0)).to eq(1)
      expect(described_class.kumi_pow(5, 1)).to eq(5)
      expect(described_class.kumi_pow(0, 5)).to eq(0)
      expect(described_class.kumi_pow(1, 5)).to eq(1)
    end

    it "handles negative exponents" do
      expect(described_class.kumi_pow(2, -3)).to eq(0.125)
      expect(described_class.kumi_pow(4, -2)).to eq(0.0625)
    end

    it "handles float exponents" do
      expect(described_class.kumi_pow(4, 0.5)).to eq(2.0)
      expect(described_class.kumi_pow(27, (1.0/3))).to be_within(0.001).of(3.0)
    end
  end

  describe ".kumi_eq" do
    it "compares equal integers" do
      expect(described_class.kumi_eq(5, 5)).to be true
      expect(described_class.kumi_eq(3, 7)).to be false
    end

    it "compares equal floats" do
      expect(described_class.kumi_eq(2.5, 2.5)).to be true
      expect(described_class.kumi_eq(2.5, 3.0)).to be false
    end

    it "compares different types" do
      expect(described_class.kumi_eq(5, 5.0)).to be true
      expect(described_class.kumi_eq(5, 5.1)).to be false
    end

    it "compares strings" do
      expect(described_class.kumi_eq("hello", "hello")).to be true
      expect(described_class.kumi_eq("hello", "world")).to be false
    end

    it "compares booleans" do
      expect(described_class.kumi_eq(true, true)).to be true
      expect(described_class.kumi_eq(false, false)).to be true
      expect(described_class.kumi_eq(true, false)).to be false
    end

    it "compares nil" do
      expect(described_class.kumi_eq(nil, nil)).to be true
      expect(described_class.kumi_eq(nil, 5)).to be false
      expect(described_class.kumi_eq(5, nil)).to be false
    end
  end

  describe ".kumi_gt" do
    it "compares integers" do
      expect(described_class.kumi_gt(5, 3)).to be true
      expect(described_class.kumi_gt(3, 5)).to be false
      expect(described_class.kumi_gt(5, 5)).to be false
    end

    it "compares floats" do
      expect(described_class.kumi_gt(3.5, 2.1)).to be true
      expect(described_class.kumi_gt(2.1, 3.5)).to be false
    end

    it "compares mixed types" do
      expect(described_class.kumi_gt(5.1, 5)).to be true
      expect(described_class.kumi_gt(5, 5.1)).to be false
    end
  end

  describe ".kumi_ge" do
    it "compares integers" do
      expect(described_class.kumi_ge(5, 3)).to be true
      expect(described_class.kumi_ge(3, 5)).to be false
      expect(described_class.kumi_ge(5, 5)).to be true
    end

    it "compares floats" do
      expect(described_class.kumi_ge(3.5, 2.1)).to be true
      expect(described_class.kumi_ge(2.1, 3.5)).to be false
      expect(described_class.kumi_ge(2.5, 2.5)).to be true
    end
  end

  describe ".kumi_lt" do
    it "compares integers" do
      expect(described_class.kumi_lt(3, 5)).to be true
      expect(described_class.kumi_lt(5, 3)).to be false
      expect(described_class.kumi_lt(5, 5)).to be false
    end
  end

  describe ".kumi_le" do
    it "compares integers" do
      expect(described_class.kumi_le(3, 5)).to be true
      expect(described_class.kumi_le(5, 3)).to be false
      expect(described_class.kumi_le(5, 5)).to be true
    end
  end

  describe ".kumi_ne" do
    it "compares unequal values" do
      expect(described_class.kumi_ne(5, 3)).to be true
      expect(described_class.kumi_ne(5, 5)).to be false
      expect(described_class.kumi_ne("hello", "world")).to be true
      expect(described_class.kumi_ne("hello", "hello")).to be false
    end
  end

  describe ".kumi_and" do
    it "performs logical AND" do
      expect(described_class.kumi_and(true, true)).to be true
      expect(described_class.kumi_and(true, false)).to be false
      expect(described_class.kumi_and(false, true)).to be false
      expect(described_class.kumi_and(false, false)).to be false
    end

    it "handles truthy/falsy values" do
      expect(described_class.kumi_and(5, "hello")).to eq("hello")
      expect(described_class.kumi_and(0, "hello")).to eq("hello")
      expect(described_class.kumi_and(nil, "hello")).to be nil
      expect(described_class.kumi_and(false, "hello")).to be false
    end
  end

  describe ".kumi_or" do
    it "performs logical OR" do
      expect(described_class.kumi_or(true, true)).to be true
      expect(described_class.kumi_or(true, false)).to be true
      expect(described_class.kumi_or(false, true)).to be true
      expect(described_class.kumi_or(false, false)).to be false
    end

    it "handles truthy/falsy values" do
      expect(described_class.kumi_or(5, "hello")).to eq(5)
      expect(described_class.kumi_or(nil, "hello")).to eq("hello")
      expect(described_class.kumi_or(false, "hello")).to eq("hello")
      expect(described_class.kumi_or(false, nil)).to be nil
    end
  end

  describe ".kumi_not" do
    it "performs logical NOT" do
      expect(described_class.kumi_not(true)).to be false
      expect(described_class.kumi_not(false)).to be true
    end

    it "handles truthy/falsy values" do
      expect(described_class.kumi_not(5)).to be false
      expect(described_class.kumi_not("hello")).to be false
      expect(described_class.kumi_not(nil)).to be true
      expect(described_class.kumi_not(0)).to be false
      expect(described_class.kumi_not("")).to be false
    end
  end
end