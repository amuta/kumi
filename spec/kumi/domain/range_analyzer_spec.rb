# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Domain::RangeAnalyzer do
  describe ".analyze" do
    context "with integer ranges" do
      let(:range) { 18..65 }

      it "provides comprehensive analysis" do
        result = described_class.analyze(range)

        expect(result[:type]).to eq(:range)
        expect(result[:min]).to eq(18)
        expect(result[:max]).to eq(65)
        expect(result[:exclusive_end]).to be false
        expect(result[:size]).to eq(48) # 65-18+1
        expect(result[:boundary_values]).to eq([18, 65])
      end

      it "generates appropriate sample values" do
        result = described_class.analyze(range)
        samples = result[:sample_values]

        expect(samples).to include(18, 65) # Boundary values
        expect(samples.all? { |v| range.include?(v) }).to be true
        expect(samples.size).to be <= 10
      end

      it "generates invalid sample values" do
        result = described_class.analyze(range)
        invalid_samples = result[:invalid_samples]

        expect(invalid_samples).to include(17, 66) # Just outside boundaries
        expect(invalid_samples.none? { |v| range.include?(v) }).to be true
      end
    end

    context "with exclusive ranges" do
      let(:range) { 0.0...1.0 }

      it "correctly identifies exclusive end" do
        result = described_class.analyze(range)

        expect(result[:exclusive_end]).to be true
        expect(result[:min]).to eq(0.0)
        expect(result[:max]).to eq(1.0)
      end

      it "generates invalid samples including the excluded end" do
        result = described_class.analyze(range)
        invalid_samples = result[:invalid_samples]

        expect(invalid_samples).to include(1.0) # Excluded end value
        expect(invalid_samples.none? { |v| range.include?(v) }).to be true
      end

      it "does not include excluded end in sample values" do
        result = described_class.analyze(range)
        samples = result[:sample_values]

        expect(samples).not_to include(1.0)
        expect(samples.all? { |v| range.include?(v) }).to be true
      end
    end

    context "with float ranges" do
      let(:range) { -10.5..50.2 }

      it "marks continuous ranges appropriately" do
        result = described_class.analyze(range)

        expect(result[:size]).to eq(:continuous)
        expect(result[:min]).to eq(-10.5)
        expect(result[:max]).to eq(50.2)
      end

      it "generates float sample values" do
        result = described_class.analyze(range)
        samples = result[:sample_values]

        expect(samples).to include(-10.5, 50.2) # Boundary values
        expect(samples.all? { |v| v.is_a?(Float) || v.is_a?(Integer) }).to be true
        expect(samples.all? { |v| range.include?(v) }).to be true
      end
    end

    context "with large integer ranges" do
      let(:range) { 1..100_000 }

      it "marks large ranges appropriately" do
        result = described_class.analyze(range)

        expect(result[:size]).to eq(:large)
        expect(result[:min]).to eq(1)
        expect(result[:max]).to eq(100_000)
      end

      it "still generates boundary samples for large ranges" do
        result = described_class.analyze(range)
        samples = result[:sample_values]

        expect(samples).to include(1, 100_000)
        expect(samples.size).to be <= 10
      end
    end

    context "with small ranges" do
      let(:range) { 5..7 }

      it "calculates exact size for small ranges" do
        result = described_class.analyze(range)

        expect(result[:size]).to eq(3) # 7-5+1
        expect(result[:type]).to eq(:range)
      end

      it "includes all values in samples for very small ranges" do
        tiny_range = 1..3
        result = described_class.analyze(tiny_range)
        samples = result[:sample_values]

        expect(samples).to include(1, 2, 3)
      end
    end

    context "with single-value ranges" do
      let(:range) { 42..42 }

      it "handles single-value ranges correctly" do
        result = described_class.analyze(range)

        expect(result[:size]).to eq(1)
        expect(result[:min]).to eq(42)
        expect(result[:max]).to eq(42)
        expect(result[:sample_values]).to include(42)
      end
    end

    context "edge cases" do
      it "handles ranges with negative values" do
        range = -100..-50
        result = described_class.analyze(range)

        expect(result[:min]).to eq(-100)
        expect(result[:max]).to eq(-50)
        expect(result[:size]).to eq(51)
        expect(result[:sample_values]).to include(-100, -50)
        expect(result[:invalid_samples]).to include(-101, -49)
      end

      it "handles ranges crossing zero" do
        range = -5..5
        result = described_class.analyze(range)

        expect(result[:size]).to eq(11)
        expect(result[:sample_values]).to include(-5, 0, 5)
        expect(result[:invalid_samples]).to include(-6, 6)
      end
    end
  end

  describe "integration with range validation" do
    # RangeAnalyzer focuses on analysis, not validation
    # Validation is tested through Domain::Validator specs
    it "provides analysis that supports range validation" do
      range = 10..20
      analysis = described_class.analyze(range)

      # The analysis should provide enough info for validation
      expect(analysis[:min]).to eq(10)
      expect(analysis[:max]).to eq(20)
      expect(analysis[:exclusive_end]).to be false

      # Test that the range covers expected behavior
      expect(range.include?(15)).to be true
      expect(range.include?(9)).to be false
      expect(range.include?(21)).to be false
    end

    it "provides analysis for exclusive ranges" do
      range = 0.0...1.0
      analysis = described_class.analyze(range)

      expect(analysis[:exclusive_end]).to be true
      expect(analysis[:invalid_samples]).to include(1.0) # The excluded value

      # Test that the range covers expected behavior
      expect(range.include?(0.0)).to be true
      expect(range.include?(0.999)).to be true
      expect(range.include?(1.0)).to be false
    end
  end
end
