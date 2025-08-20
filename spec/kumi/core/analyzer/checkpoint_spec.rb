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
      ENV["KUMI_RESUME_AT"] = "TypeChecker"
      expect(described_class.enabled?).to be true
    end

    it "returns true when stop_after is set" do
      ENV["KUMI_STOP_AFTER"] = "LowerToIRPass"
      expect(described_class.enabled?).to be true
    end
  end

  describe "configuration methods" do
    it "has sensible defaults" do
      expect(described_class.dir).to eq("tmp/analysis_snapshots")
      expect(described_class.phases).to eq([:before, :after])
      expect(described_class.formats).to eq(["marshal"])
    end

    it "reads from environment variables" do
      ENV["KUMI_CHECKPOINT_DIR"] = temp_dir
      ENV["KUMI_CHECKPOINT_PHASE"] = "before,after"
      ENV["KUMI_CHECKPOINT_FORMAT"] = "json,marshal"
      
      expect(described_class.dir).to eq(temp_dir)
      expect(described_class.phases).to eq([:before, :after])
      expect(described_class.formats).to eq(["json", "marshal"])
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
end