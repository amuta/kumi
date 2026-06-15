# frozen_string_literal: true

RSpec.describe Kumi::Core::Analyzer::PassManager do
  include ASTFactory

  describe ".new" do
    it "stores passes in order" do
      passes = [Kumi::Core::Analyzer::Passes::NameIndexerPass, Kumi::Core::Analyzer::Passes::InputCollectorPass]
      manager = described_class.new(passes)

      expect(manager.passes).to eq(passes)
    end

    it "initializes with empty error list" do
      passes = [Kumi::Core::Analyzer::Passes::NameIndexerPass]
      manager = described_class.new(passes)

      expect(manager.errors).to be_empty
    end
  end

  describe "#run" do
    context "with single pass" do
      it "executes pass and returns result with state and phase info" do
        passes = [Kumi::Core::Analyzer::Passes::NameIndexerPass]
        manager = described_class.new(passes)

        syntax_tree = syntax(:root, [], [attr(:x, lit(1))], [], loc: loc)
        result = manager.run(syntax_tree)

        expect(result).to be_a(Kumi::Core::Analyzer::ExecutionResult)
        expect(result.final_state).to be_a(Kumi::Core::Analyzer::AnalysisState)
        expect(result.final_state).to have_key(:declarations)
      end

      it "captures errors from pass execution" do
        passes = [Kumi::Core::Analyzer::Passes::NameIndexerPass]
        manager = described_class.new(passes)

        dup_attr = attr(:dup, lit(1))
        dup_attr_two = attr(:dup, lit(2))
        syntax_tree = syntax(:root, [], [dup_attr, dup_attr_two], [], loc: loc)

        result = manager.run(syntax_tree)

        expect(result.errors).not_to be_empty
        expect(result.errors.first).to be_a(Kumi::Core::Analyzer::PassFailure)
      end
    end

    context "with multiple passes" do
      it "executes passes in sequence and accumulates state" do
        passes = [
          Kumi::Core::Analyzer::Passes::NameIndexerPass,
          Kumi::Core::Analyzer::Passes::InputCollectorPass
        ]
        manager = described_class.new(passes)

        items_input = input_decl(:items, :array)
        value_decl = attr(:total, lit(100))
        syntax_tree = syntax(:root, [items_input], [value_decl], [], loc: loc)

        result = manager.run(syntax_tree)

        expect(result.final_state).to have_key(:declarations)
        expect(result.final_state).to have_key(:input_metadata)
      end

      it "stops execution on first error" do
        passes = [
          Kumi::Core::Analyzer::Passes::NameIndexerPass,
          Kumi::Core::Analyzer::Passes::InputCollectorPass
        ]
        manager = described_class.new(passes)

        dup_attr = attr(:dup, lit(1))
        dup_attr_two = attr(:dup, lit(2))
        syntax_tree = syntax(:root, [], [dup_attr, dup_attr_two], [], loc: loc)

        result = manager.run(syntax_tree)

        # Should have stopped and not continued to next pass
        expect(result.failed?).to be true
        expect(result.final_state).not_to have_key(:input_metadata)
      end

      it "tracks which phase failed" do
        passes = [
          Kumi::Core::Analyzer::Passes::NameIndexerPass,
          Kumi::Core::Analyzer::Passes::InputCollectorPass
        ]
        manager = described_class.new(passes)

        dup_attr = attr(:dup, lit(1))
        dup_attr_two = attr(:dup, lit(2))
        syntax_tree = syntax(:root, [], [dup_attr, dup_attr_two], [], loc: loc)

        result = manager.run(syntax_tree)

        expect(result.failed_at_phase).to eq(0) # NameIndexerPass is phase 0
      end
    end

    context "when all passes succeed" do
      it "marks result as successful" do
        passes = [
          Kumi::Core::Analyzer::Passes::NameIndexerPass,
          Kumi::Core::Analyzer::Passes::InputCollectorPass
        ]
        manager = described_class.new(passes)

        syntax_tree = syntax(:root, [], [attr(:x, lit(1))], [], loc: loc)
        result = manager.run(syntax_tree)

        expect(result.succeeded?).to be true
        expect(result.failed?).to be false
      end
    end

    context "compile-time budget" do
      # A pass that runs longer than its budget, to prove a runaway pass fails
      # fast (and locatably) instead of hanging the whole compile.
      let(:slow_pass) do
        Class.new(Kumi::Core::Analyzer::Passes::PassBase) do
          def self.name = "SlowPass"

          def run(_errors)
            sleep 0.5
            state
          end
        end
      end

      it "fails the slow pass with a PassFailure naming it" do
        manager = described_class.new([slow_pass])
        syntax_tree = syntax(:root, [], [attr(:x, lit(1))], [], loc: loc)

        result = manager.run(syntax_tree, nil, [], pass_budget_ms: 100)

        expect(result.failed?).to be true
        expect(result.errors.first.message).to include("exceeded its compile budget")
      end

      it "lets a pass finish when the budget is generous" do
        manager = described_class.new([slow_pass])
        syntax_tree = syntax(:root, [], [attr(:x, lit(1))], [], loc: loc)

        result = manager.run(syntax_tree, nil, [], pass_budget_ms: 5_000)

        expect(result.succeeded?).to be true
      end

      it "treats a non-positive budget as disabled (no timeout)" do
        manager = described_class.new([slow_pass])
        syntax_tree = syntax(:root, [], [attr(:x, lit(1))], [], loc: loc)

        result = manager.run(syntax_tree, nil, [], pass_budget_ms: 0)

        expect(result.succeeded?).to be true
      end
    end
  end
end
