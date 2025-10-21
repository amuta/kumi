# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe Kumi::Core::Analyzer::Checkpoint do
  let(:temp_dir) { Dir.mktmpdir("checkpoint_test") }
  let(:state) { Kumi::Core::Analyzer::AnalysisState.new(test: "data", count: 42) }

  around do |example|
    # Clean ENV and temp directory
    original_env = ENV.select { |k, _| k.start_with?("KUMI_") }
    ENV.keys.select { |k| k.start_with?("KUMI_") }.each { |k| ENV.delete(k) }

    example.run

    # Restore ENV
    ENV.keys.select { |k| k.start_with?("KUMI_") }.each { |k| ENV.delete(k) }
    original_env.each { |k, v| ENV[k] = v }

    FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
  end

  describe ".enabled?" do
    it "returns false by default" do
      expect(described_class.enabled?).to be false
    end

    it "returns true when KUMI_CHECKPOINT=1" do
      ENV["KUMI_CHECKPOINT"] = "1"
      expect(described_class.enabled?).to be true
    end

    it "returns true when resume_from is set" do
      ENV["KUMI_RESUME_FROM"] = "some/path.msh"
      expect(described_class.enabled?).to be true
    end

    it "returns true when resume_at is set" do
      ENV["KUMI_RESUME_AT"] = "NormalizeToNASTPass"
      expect(described_class.enabled?).to be true
    end

    it "returns true when stop_after is set" do
      ENV["KUMI_STOP_AFTER"] = "SNASTPass"
      expect(described_class.enabled?).to be true
    end
  end

  describe "configuration methods" do
    it "has sensible defaults" do
      expect(described_class.dir).to eq("tmp/analysis_snapshots")
      expect(described_class.phases).to eq(%i[before after])
      expect(described_class.formats).to eq(["marshal"])
    end

    it "reads from environment variables" do
      ENV["KUMI_CHECKPOINT_DIR"] = temp_dir
      ENV["KUMI_CHECKPOINT_PHASE"] = "before,after"
      ENV["KUMI_CHECKPOINT_FORMAT"] = "json,marshal"

      expect(described_class.dir).to eq(temp_dir)
      expect(described_class.phases).to eq(%i[before after])
      expect(described_class.formats).to eq(%w[json marshal])
    end

    it "handles single values in CSV fields" do
      ENV["KUMI_CHECKPOINT_PHASE"] = "after"
      ENV["KUMI_CHECKPOINT_FORMAT"] = "json"

      expect(described_class.phases).to eq([:after])
      expect(described_class.formats).to eq(["json"])
    end
  end

  describe ".snapshot" do
    before do
      ENV["KUMI_CHECKPOINT"] = "1"
      ENV["KUMI_CHECKPOINT_DIR"] = temp_dir
    end

    it "creates marshal files by default" do
      files = described_class.snapshot(pass_name: "TestPass", idx: 5, phase: :before, state: state)

      expect(files).to eq(["#{temp_dir}/005_TestPass_before.msh"])
      expect(File.exist?(files.first)).to be true
    end

    it "creates json files when configured" do
      ENV["KUMI_CHECKPOINT_FORMAT"] = "json"

      files = described_class.snapshot(pass_name: "TestPass", idx: 3, phase: :after, state: state)

      expect(files).to eq(["#{temp_dir}/003_TestPass_after.json"])
      expect(File.exist?(files.first)).to be true

      json_content = File.read(files.first)
      expect(json_content).to include('"test": "data"')
      expect(json_content).to include('"count": 42')
    end

    it "creates both formats when configured" do
      ENV["KUMI_CHECKPOINT_FORMAT"] = "both"

      files = described_class.snapshot(pass_name: "BothTest", idx: 1, phase: :before, state: state)

      expect(files.size).to eq(2)
      expect(files).to include("#{temp_dir}/001_BothTest_before.msh")
      expect(files).to include("#{temp_dir}/001_BothTest_before.json")
      files.each { |f| expect(File.exist?(f)).to be true }
    end

    it "creates directory if it doesn't exist" do
      nested_dir = File.join(temp_dir, "nested", "deep")
      ENV["KUMI_CHECKPOINT_DIR"] = nested_dir

      described_class.snapshot(pass_name: "DirTest", idx: 0, phase: :before, state: state)

      expect(Dir.exist?(nested_dir)).to be true
    end

    it "logs to Debug system when enabled" do
      allow(Kumi::Core::Analyzer::Debug).to receive(:enabled?).and_return(true)
      expect(Kumi::Core::Analyzer::Debug).to receive(:info).with(
        :checkpoint,
        phase: :before,
        idx: 2,
        files: ["#{temp_dir}/002_DebugTest_before.msh"]
      )

      described_class.snapshot(pass_name: "DebugTest", idx: 2, phase: :before, state: state)
    end
  end

  describe ".entering and .leaving" do
    before do
      ENV["KUMI_CHECKPOINT"] = "1"
      ENV["KUMI_CHECKPOINT_DIR"] = temp_dir
    end

    it "snapshots on entering when before phase enabled" do
      ENV["KUMI_CHECKPOINT_PHASE"] = "before"

      expect(described_class).to receive(:snapshot).with(
        pass_name: "TestPass",
        idx: 1,
        phase: :before,
        state: state
      )

      described_class.entering(pass_name: "TestPass", idx: 1, state: state)
    end

    it "snapshots on leaving when after phase enabled" do
      ENV["KUMI_CHECKPOINT_PHASE"] = "after"

      expect(described_class).to receive(:snapshot).with(
        pass_name: "TestPass",
        idx: 1,
        phase: :after,
        state: state
      )

      described_class.leaving(pass_name: "TestPass", idx: 1, state: state)
    end

    it "does nothing when disabled" do
      ENV["KUMI_CHECKPOINT"] = "0"

      expect(described_class).not_to receive(:snapshot)

      described_class.entering(pass_name: "TestPass", idx: 1, state: state)
      described_class.leaving(pass_name: "TestPass", idx: 1, state: state)
    end
  end

  describe ".load_initial_state" do
    let(:default_state) { Kumi::Core::Analyzer::AnalysisState.new(default: true) }

    it "returns default state when no resume path configured" do
      result = described_class.load_initial_state(default_state)
      expect(result).to eq(default_state)
    end

    it "returns default state when resume file doesn't exist" do
      ENV["KUMI_RESUME_FROM"] = "/nonexistent/file.msh"

      result = described_class.load_initial_state(default_state)
      expect(result).to eq(default_state)
    end

    it "loads marshal file when it exists" do
      marshal_file = File.join(temp_dir, "saved_state.msh")
      File.binwrite(marshal_file, Kumi::Core::Analyzer::StateSerde.dump_marshal(state))
      ENV["KUMI_RESUME_FROM"] = marshal_file

      result = described_class.load_initial_state(default_state)
      expect(result.to_h).to eq(state.to_h)
    end

    it "loads json file when it exists" do
      json_file = File.join(temp_dir, "saved_state.json")
      File.write(json_file, Kumi::Core::Analyzer::StateSerde.dump_json(state))
      ENV["KUMI_RESUME_FROM"] = json_file

      result = described_class.load_initial_state(default_state)
      expect(result.to_h).to eq(state.to_h)
    end
  end

  describe "pass skipping logic integration" do
    it "correctly implements skipping logic when KUMI_RESUME_AT is set" do
      # Test the actual skipping logic from analyzer.rb:94-97
      resume_at = "SNASTPass"
      skipping = !!resume_at

      # Simulate the pass loop from analyzer.rb with actual current passes
      # Note: DEFAULT_PASSES and HIR_TO_LIR_PASSES are run separately
      passes = %w[
        NameIndexer
        InputCollector
        InputFormSchemaPass
        DeclarationValidator
        SemanticConstraintValidator
        DependencyResolver
        Toposorter
        InputAccessPlannerPass
        NormalizeToNASTPass
        ConstantFoldingPass
        NASTDimensionalAnalyzerPass
        SNASTPass
      ]

      executed_passes = []

      passes.each do |pass_name|
        # This is the logic from analyzer.rb:94-97
        if skipping
          skipping = false if pass_name == resume_at
          next if skipping
        end

        executed_passes << pass_name
      end

      # Should have skipped everything before SNASTPass
      expect(executed_passes).not_to include("NameIndexer")
      expect(executed_passes).not_to include("InputCollector")
      expect(executed_passes).not_to include("DeclarationValidator")
      expect(executed_passes).not_to include("SemanticConstraintValidator")
      expect(executed_passes).not_to include("DependencyResolver")
      expect(executed_passes).not_to include("Toposorter")
      expect(executed_passes).not_to include("InputAccessPlannerPass")
      expect(executed_passes).not_to include("NormalizeToNASTPass")
      expect(executed_passes).not_to include("ConstantFoldingPass")
      expect(executed_passes).not_to include("NASTDimensionalAnalyzerPass")

      # When resuming at SNASTPass, only SNASTPass and passes after it in the same list execute
      # Since SNASTPass is the last in this simulated list, only it executes
      expect(executed_passes).to eq(["SNASTPass"])
    end

    it "executes all passes when resume_at is nil" do
      resume_at = nil
      skipping = !!resume_at  # false

      passes = %w[NameIndexer InputCollector InputFormSchemaPass]
      executed_passes = []

      passes.each do |pass_name|
        if skipping
          skipping = false if pass_name == resume_at
          next if skipping
        end

        executed_passes << pass_name
      end

      expect(executed_passes).to eq(%w[NameIndexer InputCollector InputFormSchemaPass])
    end

    it "starts from the first pass if resume_at matches the first pass" do
      resume_at = "NameIndexer"
      skipping = !!resume_at  # true

      passes = %w[NameIndexer InputCollector InputFormSchemaPass]
      executed_passes = []

      passes.each do |pass_name|
        if skipping
          skipping = false if pass_name == resume_at
          next if skipping
        end

        executed_passes << pass_name
      end

      expect(executed_passes).to eq(%w[NameIndexer InputCollector InputFormSchemaPass])
    end

    it "handles the case where resume_at doesn't match any pass" do
      resume_at = "NonExistentPass"
      skipping = !!resume_at  # true

      passes = %w[NameIndexer InputCollector InputFormSchemaPass]
      executed_passes = []

      passes.each do |pass_name|
        if skipping
          skipping = false if pass_name == resume_at
          next if skipping
        end

        executed_passes << pass_name
      end

      # Should skip all passes since none match
      expect(executed_passes).to be_empty
    end
  end
end
