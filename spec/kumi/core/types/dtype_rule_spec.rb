# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Types::DtypeRule do
  let(:int)    { Kumi::Core::Types.scalar(:integer) }
  let(:float)  { Kumi::Core::Types.scalar(:float) }
  let(:string) { Kumi::Core::Types.scalar(:string) }

  describe ".same_as" do
    it "returns the type of the named parameter" do
      rule = described_class.same_as(:value)
      expect(rule.call({ value: int })).to eq(int)
    end
  end

  describe ".promote" do
    it "promotes the named parameters" do
      rule = described_class.promote(:a, :b)
      expect(rule.call({ a: int, b: float })).to eq(float)
    end
  end

  describe ".element_of" do
    it "extracts the element type of an array parameter" do
      rule = described_class.element_of(:collection)
      expect(rule.call({ collection: Kumi::Core::Types.array(int) })).to eq(int)
    end

    it "promotes the element types of a tuple parameter" do
      rule = described_class.element_of(:pair)
      expect(rule.call({ pair: Kumi::Core::Types.tuple([int, float]) })).to eq(float)
    end
  end

  describe ".unify" do
    it "unifies two parameters" do
      rule = described_class.unify(:left, :right)
      expect(rule.call({ left: int, right: float })).to eq(float)
    end

    it "returns the shared type when both are equal" do
      rule = described_class.unify(:a, :b)
      expect(rule.call({ a: int, b: int })).to eq(int)
    end
  end

  describe ".scalar" do
    it "returns a constant scalar type" do
      rule = described_class.scalar(:integer)
      expect(rule.call({})).to eq(int)
    end
  end

  describe ".array" do
    it "builds a constant array from a kind" do
      rule = described_class.array(:integer)
      expect(rule.call({})).to eq(Kumi::Core::Types.array(int))
    end

    it "builds an array from a named parameter's type" do
      rule = described_class.array(:elem)
      expect(rule.call({ elem: int })).to eq(Kumi::Core::Types.array(int))
    end
  end

  describe ".tuple" do
    it "builds a constant tuple from kinds" do
      rule = described_class.tuple(:integer, :float)
      expect(rule.call({})).to eq(Kumi::Core::Types.tuple([int, float]))
    end

    it "builds a tuple from a named parameter holding an array of types" do
      rule = described_class.tuple(:types)
      expect(rule.call({ types: [int, string] })).to eq(Kumi::Core::Types.tuple([int, string]))
    end
  end
end
