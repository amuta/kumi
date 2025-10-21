# frozen_string_literal: true

RSpec.describe Kumi::Core::Analyzer::ExecutionResult do
  let(:state) { Kumi::Core::Analyzer::AnalysisState.new(test: "data") }

  describe ".success" do
    it "creates successful result with final state" do
      result = described_class.success(final_state: state)

      expect(result.succeeded?).to be true
      expect(result.failed?).to be false
      expect(result.final_state).to eq(state)
    end

    it "has empty errors on success" do
      result = described_class.success(final_state: state)

      expect(result.errors).to be_empty
    end

    it "has no failed phase on success" do
      result = described_class.success(final_state: state)

      expect(result.failed_at_phase).to be_nil
    end
  end

  describe ".failure" do
    it "creates failed result with errors" do
      error = Kumi::Core::Analyzer::PassFailure.new(
        message: "Test error",
        phase: 1,
        pass_name: "TestPass",
        location: nil
      )

      result = described_class.failure(
        final_state: state,
        errors: [error],
        failed_at_phase: 1
      )

      expect(result.succeeded?).to be false
      expect(result.failed?).to be true
      expect(result.errors.size).to eq(1)
      expect(result.failed_at_phase).to eq(1)
    end
  end

  describe "#succeeded?" do
    it "returns true when result is successful" do
      result = described_class.success(final_state: state)
      expect(result.succeeded?).to be true
    end

    it "returns false when result is failed" do
      error = Kumi::Core::Analyzer::PassFailure.new(
        message: "Error",
        phase: 0,
        pass_name: "Pass",
        location: nil
      )
      result = described_class.failure(
        final_state: state,
        errors: [error],
        failed_at_phase: 0
      )
      expect(result.succeeded?).to be false
    end
  end

  describe "#failed?" do
    it "returns true when result is failed" do
      error = Kumi::Core::Analyzer::PassFailure.new(
        message: "Error",
        phase: 0,
        pass_name: "Pass",
        location: nil
      )
      result = described_class.failure(
        final_state: state,
        errors: [error],
        failed_at_phase: 0
      )
      expect(result.failed?).to be true
    end

    it "returns false when result is successful" do
      result = described_class.success(final_state: state)
      expect(result.failed?).to be false
    end
  end

  describe "#error_count" do
    it "returns number of errors" do
      error1 = Kumi::Core::Analyzer::PassFailure.new(
        message: "Error 1",
        phase: 0,
        pass_name: "Pass",
        location: nil
      )
      error2 = Kumi::Core::Analyzer::PassFailure.new(
        message: "Error 2",
        phase: 0,
        pass_name: "Pass",
        location: nil
      )
      result = described_class.failure(
        final_state: state,
        errors: [error1, error2],
        failed_at_phase: 0
      )

      expect(result.error_count).to eq(2)
    end

    it "returns 0 for successful result" do
      result = described_class.success(final_state: state)
      expect(result.error_count).to eq(0)
    end
  end
end
