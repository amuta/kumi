# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Types::Builder do
  describe ".array" do
    it "creates array types with valid element types" do
      result = described_class.array(:string)
      expect(result).to eq({ array: :string })
    end

    it "creates nested array types" do
      result = described_class.array({ array: :integer })
      expect(result).to eq({ array: { array: :integer } })
    end

    it "creates array types with hash element types" do
      result = described_class.array({ hash: %i[string integer] })
      expect(result).to eq({ array: { hash: %i[string integer] } })
    end

    it "raises error for invalid element types" do
      expect do
        described_class.array(:invalid)
      end.to raise_error(ArgumentError, /Invalid array element type/)
    end
  end

  describe ".hash" do
    it "creates hash types with valid key and value types" do
      result = described_class.hash(:string, :integer)
      expect(result).to eq({ hash: %i[string integer] })
    end

    it "creates nested hash types" do
      result = described_class.hash(:string, { array: :float })
      expect(result).to eq({ hash: [:string, { array: :float }] })
    end

    it "creates hash types with array key types" do
      result = described_class.hash({ array: :string }, :integer)
      expect(result).to eq({ hash: [{ array: :string }, :integer] })
    end

    it "raises error for invalid key types" do
      expect do
        described_class.hash(:invalid, :string)
      end.to raise_error(ArgumentError, /Invalid hash key type/)
    end

    it "raises error for invalid value types" do
      expect do
        described_class.hash(:string, :invalid)
      end.to raise_error(ArgumentError, /Invalid hash value type/)
    end
  end
end
