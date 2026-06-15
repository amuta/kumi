# frozen_string_literal: true

RSpec.describe Kumi::Core::Analyzer::PassFailure do
  describe ".new" do
    it "stores error message and phase info" do
      failure = described_class.new(
        message: "Duplicate definition",
        phase: 0,
        pass_name: "NameIndexerPass",
        location: Kumi::Syntax::Location.new(file: "test.kumi", line: 5, column: 1)
      )

      expect(failure.message).to eq("Duplicate definition")
      expect(failure.phase).to eq(0)
      expect(failure.pass_name).to eq("NameIndexerPass")
      expect(failure.location).to be_a(Kumi::Syntax::Location)
    end

    it "allows nil location" do
      failure = described_class.new(
        message: "Generic error",
        phase: 1,
        pass_name: "InputCollectorPass",
        location: nil
      )

      expect(failure.location).to be_nil
      expect(failure.message).to eq("Generic error")
    end
  end

  describe "#to_s" do
    it "formats error with location if available" do
      location = Kumi::Syntax::Location.new(file: "test.kumi", line: 5, column: 1)
      failure = described_class.new(
        message: "Duplicate definition",
        phase: 0,
        pass_name: "NameIndexerPass",
        location: location
      )

      output = failure.to_s
      expect(output).to include("Duplicate definition")
      expect(output).to include("NameIndexerPass")
    end

    it "formats error without location" do
      failure = described_class.new(
        message: "Generic error",
        phase: 1,
        pass_name: "InputCollectorPass",
        location: nil
      )

      output = failure.to_s
      expect(output).to include("Generic error")
      expect(output).to include("InputCollectorPass")
    end
  end
end
