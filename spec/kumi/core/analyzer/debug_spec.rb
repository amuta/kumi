# frozen_string_literal: true

RSpec.describe Kumi::Analyzer do
  describe "debug system" do
    let(:schema) { double(:schema) }
    let(:errors) { [] }
    let(:initial_state) { Kumi::Core::Analyzer::AnalysisState.new({}) }

    class NoopPass
      def initialize(_, state); @state = state; end
      def run(_errors); @state end
    end

    class WriterPass
      def initialize(_, state); @state = state; end
      def run(_errors); @state.with(:x, 1) end
    end

    class ErrorPass
      def initialize(_, state); @state = state; end
      def run(_errors); raise "boom" end
    end

    module Nested
      module Module
        class BazPass
          def initialize(_, state); @state = state; end
          def run(_errors); @state end
        end
      end
    end

    before do
      # Reset debug state
      Thread.current[Kumi::Core::Analyzer::Debug::KEY] = nil
    end

    describe "when enabled" do
      before do
        allow(Kumi::Core::Analyzer::Debug).to receive(:enabled?).and_return(true)
        allow(Kumi::Core::Analyzer::Debug).to receive(:reset_log)
        allow(Kumi::Core::Analyzer::Debug).to receive(:drain_log).and_return([])
        allow(Kumi::Core::Analyzer::Debug).to receive(:diff_state).and_return({})
        allow(Kumi::Core::Analyzer::Debug).to receive(:emit)
      end

      it "emits one event per pass with pass name, timing, diff" do
        described_class.run_analysis_passes(schema, [NoopPass, WriterPass], initial_state, errors)

        expect(Kumi::Core::Analyzer::Debug).to have_received(:reset_log).twice
        expect(Kumi::Core::Analyzer::Debug).to have_received(:diff_state).twice
        expect(Kumi::Core::Analyzer::Debug).to have_received(:emit).twice

        # Check the emission structure
        expect(Kumi::Core::Analyzer::Debug).to have_received(:emit).with(
          hash_including(
            pass: "WriterPass",
            elapsed_ms: a_value >= 0,
            diff: {},
            logs: []
          )
        )
      end

      it "passes correct before/after state to diff_state" do
        diff_args = []
        allow(Kumi::Core::Analyzer::Debug).to receive(:diff_state) do |before, after|
          diff_args << [before, after]
          {}
        end

        described_class.run_analysis_passes(schema, [WriterPass], initial_state, errors)

        before, after = diff_args.last
        expect(before).to be_a(Hash)
        expect(after).to be_a(Hash)
        expect(before).not_to have_key(:x)
        expect(after[:x]).to eq(1)
      end

      it "uses short class name for nested passes" do
        described_class.run_analysis_passes(schema, [Nested::Module::BazPass], initial_state, errors)

        expect(Kumi::Core::Analyzer::Debug).to have_received(:emit).with(
          hash_including(pass: "BazPass")
        )
      end

      it "drains a fresh buffer per pass" do
        allow(Kumi::Core::Analyzer::Debug).to receive(:drain_log).and_return(
          [{level: :info, id: :a}, {level: :info, id: :b}],
          [{level: :info, id: :c}]
        )
        
        emits = []
        allow(Kumi::Core::Analyzer::Debug).to receive(:emit) { |h| emits << h }

        described_class.run_analysis_passes(schema, [NoopPass, NoopPass], initial_state, errors)
        
        expect(emits[0][:logs].size).to eq(2)
        expect(emits[1][:logs].size).to eq(1)
        expect(Kumi::Core::Analyzer::Debug).to have_received(:reset_log).twice
      end

      it "flushes logs and emits error payload on exception" do
        allow(Kumi::Core::Analyzer::Debug).to receive(:drain_log).and_return([{level: :info, id: :pre_error}])

        expect {
          described_class.run_analysis_passes(schema, [ErrorPass], initial_state, errors)
        }.to raise_error(RuntimeError, /boom/)

        expect(Kumi::Core::Analyzer::Debug).to have_received(:emit).with(
          hash_including(
            pass: "ErrorPass",
            elapsed_ms: a_value >= 0,
            logs: array_including(
              hash_including(level: :info, id: :pre_error),
              hash_including(level: :error, id: :exception, message: "boom")
            )
          )
        )
      end

      context "with immutability guard enabled" do
        around do |example|
          original = ENV["KUMI_DEBUG_REQUIRE_FROZEN"]
          ENV["KUMI_DEBUG_REQUIRE_FROZEN"] = "1"
          example.run
          ENV["KUMI_DEBUG_REQUIRE_FROZEN"] = original
        end

        it "raises if state contains unfrozen objects" do
          mutable_pass = Class.new do
            def self.name; "MutablePass"; end
            def initialize(_, state); @state = state; end
            def run(_errors); @state.with(:mutable, [1, 2, 3]) end  # Array is mutable
          end

          expect {
            described_class.run_analysis_passes(schema, [mutable_pass], initial_state, errors)
          }.to raise_error(/State\[mutable\] not frozen/)
        end

        it "allows frozen values" do
          frozen_pass = Class.new do
            def self.name; "FrozenPass"; end
            def initialize(_, state); @state = state; end
            def run(_errors); @state.with(:frozen, [1, 2, 3].freeze) end
          end

          expect {
            described_class.run_analysis_passes(schema, [frozen_pass], initial_state, errors)
          }.not_to raise_error
        end

        it "allows primitives (numbers, symbols, booleans)" do
          primitive_pass = Class.new do
            def self.name; "PrimitivePass"; end
            def initialize(_, state); @state = state; end
            def run(_errors) 
              @state.with(:num, 42).with(:sym, :test).with(:bool, true).with(:nil_val, nil)
            end
          end

          expect {
            described_class.run_analysis_passes(schema, [primitive_pass], initial_state, errors)
          }.not_to raise_error
        end
      end
    end

    describe "when disabled" do
      before do
        allow(Kumi::Core::Analyzer::Debug).to receive(:enabled?).and_return(false)
        allow(Kumi::Core::Analyzer::Debug).to receive(:emit)
        allow(Kumi::Core::Analyzer::Debug).to receive(:reset_log)
        allow(Kumi::Core::Analyzer::Debug).to receive(:diff_state)
      end

      it "does not call debug hooks" do
        described_class.run_analysis_passes(schema, [NoopPass], initial_state, errors)

        expect(Kumi::Core::Analyzer::Debug).not_to have_received(:emit)
        expect(Kumi::Core::Analyzer::Debug).not_to have_received(:reset_log)
        expect(Kumi::Core::Analyzer::Debug).not_to have_received(:diff_state)
      end
    end
  end
end