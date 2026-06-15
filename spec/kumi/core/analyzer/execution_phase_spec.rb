# frozen_string_literal: true

RSpec.describe Kumi::Core::Analyzer::ExecutionPhase do
  describe ".new" do
    it "stores pass class and index" do
      phase = described_class.new(
        pass_class: Kumi::Core::Analyzer::Passes::NameIndexerPass,
        index: 0
      )

      expect(phase.pass_class).to eq(Kumi::Core::Analyzer::Passes::NameIndexerPass)
      expect(phase.index).to eq(0)
    end
  end

  describe "#pass_name" do
    it "returns readable pass name" do
      phase = described_class.new(
        pass_class: Kumi::Core::Analyzer::Passes::NameIndexerPass,
        index: 0
      )

      expect(phase.pass_name).to eq("NameIndexerPass")
    end

    it "handles nested class names" do
      # Create a test pass class
      test_class = Class.new do
        def self.name
          "Kumi::Core::Analyzer::Passes::TestPass"
        end
      end

      phase = described_class.new(
        pass_class: test_class,
        index: 0
      )

      expect(phase.pass_name).to eq("TestPass")
    end
  end

  describe "#to_s" do
    it "returns readable string representation" do
      phase = described_class.new(
        pass_class: Kumi::Core::Analyzer::Passes::NameIndexerPass,
        index: 0
      )

      expect(phase.to_s).to include("NameIndexerPass")
      expect(phase.to_s).to include("0")
    end
  end
end
