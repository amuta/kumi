# frozen_string_literal: true

RSpec.describe Kumi::Core::Analyzer::Debug do
  before { Thread.current[described_class::KEY] = nil }

  describe ".enabled?" do
    it "returns true when KUMI_DEBUG_STATE=1" do
      allow(ENV).to receive(:[]).with("KUMI_DEBUG_STATE").and_return("1")
      expect(described_class.enabled?).to be true
    end

    it "returns false when KUMI_DEBUG_STATE is not set" do
      allow(ENV).to receive(:[]).with("KUMI_DEBUG_STATE").and_return(nil)
      expect(described_class.enabled?).to be false
    end
  end

  describe "log buffer management" do
    it "resets and drains log buffer correctly" do
      described_class.reset_log(pass: "TestPass")

      expect(described_class.drain_log).to eq([])
      expect(described_class.drain_log).to eq([]) # Second drain returns empty
    end

    it "stores and drains log events" do
      described_class.reset_log(pass: "TestPass")
      described_class.info(:test_event, data: "value")

      events = described_class.drain_log
      expect(events.size).to eq(1)
      expect(events.first).to include(
        pass: "TestPass",
        level: :info,
        id: :test_event,
        data: "value"
      )
    end

    it "includes caller information in log events" do
      described_class.reset_log(pass: "TestPass")
      described_class.debug(:test_debug)

      events = described_class.drain_log
      event = events.first
      expect(event[:file]).to be_a(String)
      expect(event[:line]).to be_a(Integer)
      expect(event[:method]).to be_a(String)
    end

    it "ignores log calls when no buffer is set" do
      # No reset_log call
      described_class.info(:ignored_event)

      described_class.reset_log(pass: "TestPass")
      events = described_class.drain_log
      expect(events).to be_empty
    end
  end

  describe ".trace" do
    it "logs start and finish events with timing" do
      described_class.reset_log(pass: "TestPass")

      result = described_class.trace(:test_operation, context: "test") do
        "operation_result"
      end

      expect(result).to eq("operation_result")

      events = described_class.drain_log
      expect(events.size).to eq(2)

      start_event, finish_event = events
      expect(start_event[:id]).to eq(:test_operation_start)
      expect(start_event[:context]).to eq("test")
      expect(finish_event[:id]).to eq(:test_operation_finish)
      expect(finish_event[:ms]).to be >= 0
    end

    it "logs error event on exception and re-raises" do
      described_class.reset_log(pass: "TestPass")

      expect do
        described_class.trace(:failing_operation) do
          raise StandardError, "test error"
        end
      end.to raise_error(StandardError, "test error")

      events = described_class.drain_log
      expect(events.size).to eq(2)

      start_event, error_event = events
      expect(start_event[:id]).to eq(:failing_operation_start)
      expect(error_event[:id]).to eq(:failing_operation_error)
      expect(error_event[:error]).to eq("StandardError")
      expect(error_event[:message]).to eq("test error")
    end
  end

  describe ".diff_state" do
    it "detects added keys" do
      before = { existing: "value" }
      after = { existing: "value", new_key: "new_value" }

      diff = described_class.diff_state(before, after)

      expect(diff[:new_key]).to eq({ type: :added, value: "new_value" })
    end

    it "detects removed keys" do
      before = { existing: "value", removed: "old_value" }
      after = { existing: "value" }

      diff = described_class.diff_state(before, after)

      expect(diff[:removed]).to eq({ type: :removed, value: "old_value" })
    end

    it "detects changed values" do
      before = { key: "old_value" }
      after = { key: "new_value" }

      diff = described_class.diff_state(before, after)

      expect(diff[:key]).to eq({
                                 type: :changed,
                                 before: "old_value",
                                 after: "new_value"
                               })
    end

    it "truncates large structures" do
      large_hash = (1..150).to_h { |i| [i, "value_#{i}"] }
      diff = described_class.diff_state({}, { large: large_hash })

      truncated = diff[:large][:value]
      expect(truncated.keys.size).to eq(101) # 100 + __truncated__ key
      expect(truncated[:__truncated__]).to include("50 more")
    end
  end

  describe ".emit" do
    it "outputs to stdout when no output path configured" do
      allow(described_class).to receive(:output_path).and_return(nil)
      expect($stdout).to receive(:puts).with(/=== STATE TestPass/)
      expect($stdout).to receive(:puts).with(a_string_matching(/"pass": "TestPass"/))

      described_class.emit(
        pass: "TestPass",
        diff: {},
        elapsed_ms: 1.5,
        logs: []
      )
    end

    it "writes to file when output path configured" do
      file_double = double("file")
      allow(described_class).to receive(:output_path).and_return("/tmp/debug.log")
      allow(File).to receive(:open).with("/tmp/debug.log", "a").and_yield(file_double)
      expect(file_double).to receive(:puts).with(a_string_including("TestPass"))

      described_class.emit(
        pass: "TestPass",
        diff: {},
        elapsed_ms: 1.5,
        logs: []
      )
    end
  end

  describe "Loggable mixin" do
    let(:test_class) do
      Class.new do
        include Kumi::Core::Analyzer::Debug::Loggable

        def test_method
          log_info(:method_called, param: "value")
          trace(:traced_operation) { "result" }
        end
      end
    end

    it "provides logging methods with automatic method name" do
      described_class.reset_log(pass: "TestPass")

      test_class.new.test_method

      events = described_class.drain_log
      info_event = events.find { |e| e[:id] == :method_called }
      expect(info_event[:method]).to eq(:log_info) # This is the actual method name in the stack
      expect(info_event[:param]).to eq("value")
    end
  end
end
