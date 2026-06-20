# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Types::Registry do
  describe ".kind?" do
    it "accepts every known scalar kind" do
      %i[string integer float decimal boolean any symbol regexp time date datetime hash null pair].each do |kind|
        expect(described_class.kind?(kind)).to be true
      end
    end

    it "rejects unknown kinds" do
      expect(described_class.kind?(:invalid)).to be false
      expect(described_class.kind?(:unknown)).to be false
      expect(described_class.kind?(:array)).to be false
      expect(described_class.kind?(:tuple)).to be false
    end
  end

  describe ".valid?" do
    context "with bare kind symbols" do
      it "accepts known scalar kinds" do
        %i[string integer float decimal boolean any].each do |kind|
          expect(described_class.valid?(kind)).to be true
        end
      end

      it "rejects unknown symbols" do
        expect(described_class.valid?(:invalid)).to be false
        expect(described_class.valid?(:unknown)).to be false
      end
    end

    context "with Type objects" do
      it "accepts ScalarType objects" do
        expect(described_class.valid?(Kumi::Core::Types.scalar(:string))).to be true
      end

      it "accepts ArrayType objects" do
        expect(described_class.valid?(Kumi::Core::Types.array(Kumi::Core::Types.scalar(:integer)))).to be true
      end

      it "accepts TupleType objects" do
        tuple = Kumi::Core::Types.tuple([Kumi::Core::Types.scalar(:string), Kumi::Core::Types.scalar(:integer)])
        expect(described_class.valid?(tuple)).to be true
      end
    end

    context "with other values" do
      it "rejects non-symbol, non-Type values" do
        expect(described_class.valid?("string")).to be false
        expect(described_class.valid?(42)).to be false
        expect(described_class.valid?(nil)).to be false
        expect(described_class.valid?({})).to be false
      end
    end
  end

  describe ".parse" do
    it "round-trips the canonical string form of every type kind" do
      [
        Kumi::Core::Types.scalar(:decimal),
        Kumi::Core::Types.array(Kumi::Core::Types.scalar(:integer)),
        Kumi::Core::Types.tuple([Kumi::Core::Types.scalar(:decimal), Kumi::Core::Types.array(Kumi::Core::Types.scalar(:float))])
      ].each do |type|
        expect(described_class.parse(type.to_s)).to eq(type)
      end
    end

    it "raises on an unknown type string" do
      expect { described_class.parse("nope") }.to raise_error(ArgumentError, /unknown type/)
    end
  end
end
