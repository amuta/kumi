# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Types::System do
  subject(:system) { described_class.default }

  let(:int)     { Kumi::Core::Types.scalar(:integer) }
  let(:float)   { Kumi::Core::Types.scalar(:float) }
  let(:decimal) { Kumi::Core::Types.scalar(:decimal) }
  let(:string)  { Kumi::Core::Types.scalar(:string) }
  let(:boolean) { Kumi::Core::Types.scalar(:boolean) }

  describe "#promote" do
    it "promotes integer and float to float" do
      expect(system.promote(int, float)).to eq(float)
    end

    it "promotes decimal as the widest numeric kind" do
      expect(system.promote(decimal, float)).to eq(decimal)
      expect(system.promote(decimal, int)).to eq(decimal)
      expect(system.promote(int, decimal)).to eq(decimal)
    end

    it "returns the single type unchanged" do
      expect(system.promote(int)).to eq(int)
    end

    it "collapses identical operands" do
      expect(system.promote(int, int, int)).to eq(int)
    end

    it "falls back to the first type for non-numeric operands" do
      expect(system.promote(string, boolean)).to eq(string)
    end
  end

  describe "#unify" do
    it "returns the type itself when both are equal" do
      expect(system.unify(int, int)).to eq(int)
    end

    it "promotes differing types" do
      expect(system.unify(int, float)).to eq(float)
    end
  end

  describe "#element_of" do
    it "extracts the element type of an array" do
      expect(system.element_of(Kumi::Core::Types.array(int))).to eq(int)
    end

    it "promotes the element types of a tuple" do
      expect(system.element_of(Kumi::Core::Types.tuple([int, float]))).to eq(float)
    end

    it "returns a scalar unchanged" do
      expect(system.element_of(int)).to eq(int)
    end
  end

  describe "#compatible?" do
    it "accepts any type for a nil constraint" do
      expect(system.compatible?(nil, string)).to be true
    end

    it "matches a scalar kind constraint" do
      expect(system.compatible?("integer", int)).to be true
      expect(system.compatible?("integer", float)).to be false
    end

    it "matches every numeric kind for the numeric category" do
      [int, float, decimal].each { |t| expect(system.compatible?("numeric", t)).to be true }
      expect(system.compatible?("numeric", string)).to be false
    end

    it "matches kinds that the old hand-written ladder missed" do
      expect(system.compatible?("decimal", decimal)).to be true
      expect(system.compatible?("boolean", boolean)).to be true
    end

    it "matches composite array/tuple constraints" do
      expect(system.compatible?("array", Kumi::Core::Types.array(int))).to be true
      expect(system.compatible?("array", int)).to be false
      expect(system.compatible?("tuple", Kumi::Core::Types.tuple([int]))).to be true
    end
  end

  describe "#match_score" do
    it "scores no match as 0" do
      expect(system.match_score("integer", float)).to eq(0)
    end

    it "scores an unconstrained match below an exact match" do
      expect(system.match_score(nil, int)).to be < system.match_score("integer", int)
    end
  end

  describe "per-target policy" do
    it "yields an independent system whose profile is named for the target" do
      ruby = described_class.for_target(:ruby)
      expect(ruby.profile.name).to eq(:ruby)
      expect(ruby.promote(decimal, int)).to eq(decimal)
    end
  end
end
