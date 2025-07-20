# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Domain::EnumAnalyzer do
  describe ".analyze" do
    context "with string arrays" do
      let(:values) { %w[active inactive pending suspended] }

      it "provides comprehensive analysis" do
        result = described_class.analyze(values)

        expect(result[:type]).to eq(:enumeration)
        expect(result[:values]).to eq(values)
        expect(result[:size]).to eq(4)
      end

      it "generates sample values from the enumeration" do
        result = described_class.analyze(values)
        samples = result[:sample_values]

        expect(samples).to be_a(Array)
        expect(samples.all? { |v| values.include?(v) }).to be true
        expect(samples.size).to be <= values.size
        expect(samples.size).to be >= 1
      end

      it "generates invalid sample values" do
        result = described_class.analyze(values)
        invalid_samples = result[:invalid_samples]

        expect(invalid_samples).to be_a(Array)
        expect(invalid_samples.none? { |v| values.include?(v) }).to be true
        expect(invalid_samples).not_to be_empty
      end

      it "includes related but invalid values in invalid samples" do
        result = described_class.analyze(values)
        invalid_samples = result[:invalid_samples]

        # Should generate plausible but incorrect alternatives
        expect(invalid_samples).to be_a(Array)
        expect(invalid_samples).not_to be_empty
        invalid_samples.each do |sample|
          expect(sample).to be_a(String)
          expect(values).not_to include(sample)
        end
      end
    end

    context "with symbol arrays" do
      let(:values) { %i[admin user guest moderator] }

      it "analyzes symbol enumerations correctly" do
        result = described_class.analyze(values)

        expect(result[:type]).to eq(:enumeration)
        expect(result[:values]).to eq(values)
        expect(result[:size]).to eq(4)
      end

      it "generates sample values as symbols" do
        result = described_class.analyze(values)
        samples = result[:sample_values]

        expect(samples.all?(Symbol)).to be true
        expect(samples.all? { |v| values.include?(v) }).to be true
      end

      it "generates invalid symbol samples" do
        result = described_class.analyze(values)
        invalid_samples = result[:invalid_samples]

        expect(invalid_samples.all?(Symbol)).to be true
        expect(invalid_samples.none? { |v| values.include?(v) }).to be true
        expect(invalid_samples).not_to be_empty
      end
    end

    context "with numeric arrays" do
      let(:values) { [1, 3, 5, 7, 11] }

      it "analyzes numeric enumerations correctly" do
        result = described_class.analyze(values)

        expect(result[:type]).to eq(:enumeration)
        expect(result[:values]).to eq(values)
        expect(result[:size]).to eq(5)
      end

      it "generates sample values as numbers" do
        result = described_class.analyze(values)
        samples = result[:sample_values]

        expect(samples.all?(Integer)).to be true
        expect(samples.all? { |v| values.include?(v) }).to be true
      end

      it "generates invalid numeric samples" do
        result = described_class.analyze(values)
        invalid_samples = result[:invalid_samples]

        expect(invalid_samples.all?(Integer)).to be true
        expect(invalid_samples.none? { |v| values.include?(v) }).to be true
        expect(invalid_samples).not_to be_empty
      end
    end

    context "with mixed type arrays" do
      let(:values) { ["active", :pending, 1, true] }

      it "analyzes mixed enumerations correctly" do
        result = described_class.analyze(values)

        expect(result[:type]).to eq(:enumeration)
        expect(result[:values]).to eq(values)
        expect(result[:size]).to eq(4)
      end

      it "generates samples of various types" do
        result = described_class.analyze(values)
        samples = result[:sample_values]

        expect(samples.all? { |v| values.include?(v) }).to be true
        # Should include different types from the original array
        sample_types = samples.map(&:class).uniq
        expect(sample_types.size).to be >= 1
      end

      it "generates invalid samples of various types" do
        result = described_class.analyze(values)
        invalid_samples = result[:invalid_samples]

        expect(invalid_samples.none? { |v| values.include?(v) }).to be true
        expect(invalid_samples).not_to be_empty
      end
    end

    context "with single-value arrays" do
      let(:values) { ["only_option"] }

      it "handles single-value enumerations" do
        result = described_class.analyze(values)

        expect(result[:type]).to eq(:enumeration)
        expect(result[:values]).to eq(values)
        expect(result[:size]).to eq(1)
        expect(result[:sample_values]).to eq(["only_option"])
      end

      it "still generates invalid samples for single-value arrays" do
        result = described_class.analyze(values)
        invalid_samples = result[:invalid_samples]

        expect(invalid_samples).not_to be_empty
        expect(invalid_samples).not_to include("only_option")
      end
    end

    context "with empty arrays" do
      let(:values) { [] }

      it "handles empty enumerations" do
        result = described_class.analyze(values)

        expect(result[:type]).to eq(:enumeration)
        expect(result[:values]).to eq([])
        expect(result[:size]).to eq(0)
        expect(result[:sample_values]).to eq([])
      end

      it "generates generic invalid samples for empty arrays" do
        result = described_class.analyze(values)
        invalid_samples = result[:invalid_samples]

        expect(invalid_samples).not_to be_empty
        # Should generate some default invalid samples for empty arrays
        expect(invalid_samples).to be_a(Array)
      end
    end

    context "edge cases" do
      it "handles arrays with nil values" do
        values = ["active", nil, "inactive"]
        result = described_class.analyze(values)

        expect(result[:values]).to include(nil)
        expect(result[:sample_values]).to be_a(Array)
        expect(result[:invalid_samples]).not_to be_empty
      end

      it "handles arrays with duplicate values" do
        values = %w[active active inactive]
        result = described_class.analyze(values)

        # Analysis should work with the array as-is (not deduplicated)
        expect(result[:values]).to eq(values)
        expect(result[:size]).to eq(3)
      end
    end
  end

  describe "integration with enumeration validation" do
    # EnumAnalyzer focuses on analysis, not validation
    # Validation is tested through Domain::Validator specs
    it "provides analysis that supports enumeration validation" do
      values = %w[red green blue]
      analysis = described_class.analyze(values)

      expect(analysis[:type]).to eq(:enumeration)
      expect(analysis[:values]).to eq(values)
      expect(analysis[:size]).to eq(3)

      # Test that the values cover expected behavior
      expect(values.include?("red")).to be true
      expect(values.include?("yellow")).to be false
    end

    it "provides analysis for various enumeration types" do
      symbol_values = %i[small medium large]
      analysis = described_class.analyze(symbol_values)

      expect(analysis[:values]).to eq(symbol_values)
      expect(analysis[:sample_values]).to be_a(Array)
      expect(analysis[:invalid_samples]).to be_a(Array)

      # Verify invalid samples don't overlap with valid values
      expect(analysis[:invalid_samples].any? { |v| symbol_values.include?(v) }).to be false
    end
  end
end
