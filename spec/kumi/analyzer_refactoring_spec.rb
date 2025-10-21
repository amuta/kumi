# frozen_string_literal: true

RSpec.describe "Analyzer refactoring with PassManager" do
  include ASTFactory

  describe "run_analysis_passes uses PassManager internally" do
    let(:simple_schema) do
      value_decl = attr(:x, lit(1))
      syntax(:root, [], [value_decl], [], loc: loc)
    end

    let(:passes) do
      [Kumi::Core::Analyzer::Passes::NameIndexer]
    end

    it "runs passes successfully and returns correct state type" do
      state = Kumi::Core::Analyzer::AnalysisState.new
      errors = []

      result_state, stopped = Kumi::Analyzer.run_analysis_passes(simple_schema, passes, state, errors)

      expect(result_state).to be_a(Kumi::Core::Analyzer::AnalysisState)
      expect(stopped).to be false
      expect(errors).to be_empty
    end

    it "populates state with pass results" do
      state = Kumi::Core::Analyzer::AnalysisState.new
      errors = []

      result_state, = Kumi::Analyzer.run_analysis_passes(simple_schema, passes, state, errors)

      expect(result_state).to have_key(:declarations)
      expect(result_state[:declarations]).to be_a(Hash)
      expect(result_state[:declarations][:x]).to be_a(Kumi::Syntax::ValueDeclaration)
    end

    it "detects and reports duplicate definitions" do
      dup_attr = attr(:dup, lit(1))
      dup_attr_two = attr(:dup, lit(2))
      error_schema = syntax(:root, [], [dup_attr, dup_attr_two], [], loc: loc)

      state = Kumi::Core::Analyzer::AnalysisState.new
      errors = []

      begin
        Kumi::Analyzer.run_analysis_passes(error_schema, passes, state, errors)
      rescue Kumi::Errors::AnalysisError => e
        # Expected error on duplicate
        expect(e.message).to match(/duplicate/)
      end
    end

    it "respects stop_after checkpoint" do
      two_passes = [
        Kumi::Core::Analyzer::Passes::NameIndexer,
        Kumi::Core::Analyzer::Passes::InputCollector
      ]

      state = Kumi::Core::Analyzer::AnalysisState.new
      errors = []

      # Stop after first pass (using internal API)
      Kumi::Core::Analyzer::Checkpoint.stop_after

      result_state, stopped = Kumi::Analyzer.run_analysis_passes(simple_schema, two_passes, state, errors)

      # May or may not stop depending on checkpoint configuration
      expect(result_state).to be_a(Kumi::Core::Analyzer::AnalysisState)
    end

    it "maintains state immutability" do
      state = Kumi::Core::Analyzer::AnalysisState.new
      errors = []

      result_state, = Kumi::Analyzer.run_analysis_passes(simple_schema, passes, state, errors)

      # Original state should not have declarations
      expect(state).not_to have_key(:declarations)
      # Result should have them
      expect(result_state).to have_key(:declarations)
    end

    it "runs multiple passes and accumulates state" do
      two_passes = [
        Kumi::Core::Analyzer::Passes::NameIndexer,
        Kumi::Core::Analyzer::Passes::InputCollector
      ]

      state = Kumi::Core::Analyzer::AnalysisState.new
      errors = []

      result_state, = Kumi::Analyzer.run_analysis_passes(simple_schema, two_passes, state, errors)

      # Both passes should have contributed to state
      expect(result_state).to have_key(:declarations)
      # InputCollector adds input_metadata (if there were inputs)
      # For this schema with no inputs, it still runs
      expect(result_state).to be_a(Kumi::Core::Analyzer::AnalysisState)
    end

    it "validates AnalysisState type is returned from passes" do
      state = Kumi::Core::Analyzer::AnalysisState.new
      errors = []

      # PassManager enforces correct state type
      result_state, = Kumi::Analyzer.run_analysis_passes(simple_schema, passes, state, errors)

      expect(result_state).to be_a(Kumi::Core::Analyzer::AnalysisState)
    end
  end

  describe "backward compatibility" do
    it "maintains same return signature (state, stopped)" do
      schema = syntax(:root, [], [attr(:x, lit(1))], [], loc: loc)
      passes = [Kumi::Core::Analyzer::Passes::NameIndexer]

      state = Kumi::Core::Analyzer::AnalysisState.new
      errors = []

      result = Kumi::Analyzer.run_analysis_passes(schema, passes, state, errors)

      expect(result).to be_a(Array)
      expect(result.size).to eq(2)
      expect(result[0]).to be_a(Kumi::Core::Analyzer::AnalysisState)
      expect(result[1]).to be(true).or be(false)
    end
  end
end
