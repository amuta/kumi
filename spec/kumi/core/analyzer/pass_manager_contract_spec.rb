# frozen_string_literal: true

RSpec.describe Kumi::Core::Analyzer::PassManager do
  describe "contract enforcement" do
    def named_pass(name, &body)
      klass = Class.new(Kumi::Core::Analyzer::Passes::PassBase, &body)
      klass.define_singleton_method(:name) { "Kumi::Test::#{name}" }
      klass
    end

    def run_manager(pass_class, initial = {})
      manager = described_class.new([pass_class])
      manager.run(nil, Kumi::Core::Analyzer::AnalysisState.new(initial), [], {})
    end

    it "raises a CompilerBug when a declared read is missing from state" do
      pass = named_pass("NeedsInputPass") do
        reads :nast_module
        def run(_errors) = state
      end

      expect { run_manager(pass) }
        .to raise_error(Kumi::Core::Errors::CompilerBug, /nast_module/)
    end

    it "raises a CompilerBug when a pass writes an undeclared key" do
      pass = named_pass("SneakyWritePass") do
        writes
        def run(_errors) = state.with(:surprise, 1)
      end

      expect { run_manager(pass) }
        .to raise_error(Kumi::Core::Errors::CompilerBug, /surprise/)
    end

    it "allows declared writes, including overwriting an existing key" do
      pass = named_pass("DeclaredWritePass") do
        reads :counter
        writes :counter
        def run(_errors) = state.with(:counter, counter + 1)
      end

      result = run_manager(pass, counter: 1)
      expect(result.failed?).to be(false)
      expect(result.final_state[:counter]).to eq(2)
    end

    it "skips enforcement for passes without a declared contract" do
      pass = named_pass("LegacyPass") do
        def run(_errors) = state.with(:anything, :goes)
      end

      result = run_manager(pass)
      expect(result.failed?).to be(false)
    end
  end
end
