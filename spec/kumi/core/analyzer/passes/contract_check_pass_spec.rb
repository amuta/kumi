# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Analyzer::Passes::ContractCheckPass do
  let(:errors) { [] }
  let(:schema) do
    # Create a minimal schema mock with required methods
    double("Schema").tap do |s|
      allow(s).to receive(:values).and_return([])
      allow(s).to receive(:traits).and_return([])
    end
  end

  def run_pass(initial_state)
    state = Kumi::Core::Analyzer::AnalysisState.new(initial_state)
    described_class.new(schema, state).run(errors)
  end

  # Helper methods
  def value_decl(name, expr)
    Kumi::Syntax::ValueDeclaration.new(name, expr)
  end

  def cascade_expr(*cases)
    Kumi::Syntax::CascadeExpression.new(cases)
  end

  def case_expr(condition, result)
    Kumi::Syntax::CaseExpression.new(condition, result)
  end

  def literal(value)
    Kumi::Syntax::Literal.new(value)
  end

  describe "required state validation" do
    context "when all required keys are present" do
      let(:valid_state) do
        {
          node_index: {},
          decl_shapes: {},
          scope_plans: {},
          declarations: {}
        }
      end

      it "passes validation without errors" do
        run_pass(valid_state)
        expect(errors).to be_empty
      end
    end

    context "when node_index is missing" do
      let(:incomplete_state) do
        {
          decl_shapes: {},
          scope_plans: {},
          declarations: {}
        }
      end

      it "reports contract violation" do
        run_pass(incomplete_state)
        expect(errors).not_to be_empty
        expect(errors.first.message).to include("Analyzer contract violation")
        expect(errors.first.message).to include("node_index")
        expect(errors.first.type).to eq(:developer)
      end
    end

    context "when decl_shapes is missing" do
      let(:incomplete_state) do
        {
          node_index: {},
          scope_plans: {},
          declarations: {}
        }
      end

      it "reports contract violation" do
        run_pass(incomplete_state)
        expect(errors).not_to be_empty
        expect(errors.first.message).to include("decl_shapes")
      end
    end

    context "when scope_plans is missing" do
      let(:incomplete_state) do
        {
          node_index: {},
          decl_shapes: {},
          declarations: {}
        }
      end

      it "reports contract violation" do
        run_pass(incomplete_state)
        expect(errors).not_to be_empty
        expect(errors.first.message).to include("scope_plans")
      end
    end

    context "when multiple keys are missing" do
      let(:incomplete_state) do
        {
          declarations: {}
        }
      end

      it "reports all missing keys" do
        run_pass(incomplete_state)
        expect(errors).not_to be_empty
        error_message = errors.first.message
        expect(error_message).to include("node_index")
        expect(error_message).to include("decl_shapes")
        expect(error_message).to include("scope_plans")
      end
    end
  end

  describe "cascade scalarization validation" do
    let(:cascade_decl) do
      value_decl(:test_cascade, 
        cascade_expr(
          case_expr(literal(true), literal("result"))
        )
      )
    end

    let(:schema_with_cascades) do
      double("Schema").tap do |s|
        allow(s).to receive(:values).and_return([cascade_decl])
        allow(s).to receive(:traits).and_return([])
      end
    end

    let(:base_state) do
      {
        node_index: {},
        decl_shapes: {},
        scope_plans: {},
        declarations: { test_cascade: cascade_decl }
      }
    end

    def run_pass_with_cascades(initial_state)
      state = Kumi::Core::Analyzer::AnalysisState.new(initial_state)
      described_class.new(schema_with_cascades, state).run(errors)
    end

    context "when cascade is properly scalarized" do
      it "passes validation for scalarized cascade with empty scope" do
        state = base_state.dup
        state[:node_index][cascade_decl.object_id] = { cascade_scalarized: true }
        state[:scope_plans][:test_cascade] = { scope: [] }

        run_pass_with_cascades(state)
        expect(errors).to be_empty
      end

      it "passes validation for non-scalarized cascade with vector scope" do
        state = base_state.dup
        state[:scope_plans][:test_cascade] = { scope: [:items] }
        # No cascade_scalarized flag set

        run_pass_with_cascades(state)
        expect(errors).to be_empty
      end
    end

    context "when cascade scalarization contract is violated" do
      it "reports error for scalarized cascade with non-empty scope" do
        state = base_state.dup
        state[:node_index][cascade_decl.object_id] = { cascade_scalarized: true }
        state[:scope_plans][:test_cascade] = { scope: [:items] }

        run_pass_with_cascades(state)
        expect(errors).not_to be_empty
        error = errors.first
        expect(error.message).to include("Cascade `test_cascade` tagged scalarized")
        expect(error.message).to include("scope=[:items]")
        expect(error.type).to eq(:developer)
        expect(error.location).to eq(cascade_decl.loc)
      end

      it "handles missing scope plan gracefully" do
        state = base_state.dup
        state[:node_index][cascade_decl.object_id] = { cascade_scalarized: true }
        # No scope_plans entry for test_cascade

        run_pass_with_cascades(state)
        expect(errors).to be_empty # Missing scope plan means empty scope array
      end

      it "handles missing node_index entry gracefully" do
        state = base_state.dup
        state[:scope_plans][:test_cascade] = { scope: [:items] }
        # No node_index entry for cascade_decl.object_id

        run_pass_with_cascades(state)
        expect(errors).to be_empty # Not tagged as scalarized, so no contract to check
      end
    end

    context "with multiple cascade declarations" do
      let(:cascade_decl_2) do
        value_decl(:test_cascade_2,
          cascade_expr(
            case_expr(literal(false), literal("other_result"))
          )
        )
      end

      it "validates all cascades independently" do
        # Create schema with both cascades
        multi_cascade_schema = double("Schema").tap do |s|
          allow(s).to receive(:values).and_return([cascade_decl, cascade_decl_2])
          allow(s).to receive(:traits).and_return([])
        end

        state = base_state.dup
        state[:declarations][:test_cascade_2] = cascade_decl_2

        # First cascade: properly scalarized
        state[:node_index][cascade_decl.object_id] = { cascade_scalarized: true }
        state[:scope_plans][:test_cascade] = { scope: [] }

        # Second cascade: contract violation
        state[:node_index][cascade_decl_2.object_id] = { cascade_scalarized: true }
        state[:scope_plans][:test_cascade_2] = { scope: [:users] }

        # Use specific schema with both cascades
        analysis_state = Kumi::Core::Analyzer::AnalysisState.new(state)
        described_class.new(multi_cascade_schema, analysis_state).run(errors)

        expect(errors.length).to eq(1)
        expect(errors.first.message).to include("test_cascade_2")
        expect(errors.first.message).to include("scope=[:users]")
      end
    end
  end

  describe "non-cascade declarations" do
    let(:value_decl_simple) do
      value_decl(:simple_value, literal(42))
    end

    it "ignores non-cascade declarations" do
      state = {
        node_index: {},
        decl_shapes: {},
        scope_plans: {},
        declarations: { simple_value: value_decl_simple }
      }

      run_pass(state)
      expect(errors).to be_empty
    end
  end

  describe "error accumulation" do
    let(:cascade_decl_1) do
      value_decl(:cascade_1, cascade_expr(case_expr(literal(true), literal("a"))))
    end

    let(:cascade_decl_2) do
      value_decl(:cascade_2, cascade_expr(case_expr(literal(true), literal("b"))))
    end

    it "accumulates multiple contract violations" do
      state = {
        # Missing required key
        decl_shapes: {},
        scope_plans: {},
        declarations: {
          cascade_1: cascade_decl_1,
          cascade_2: cascade_decl_2
        }
      }

      run_pass(state)

      # Should have at least the missing node_index error
      expect(errors.length).to be >= 1
      expect(errors.any? { |e| e.message.include?("node_index") }).to be(true)
    end
  end

  describe "state preservation" do
    it "returns the original state unchanged" do
      original_state = {
        node_index: { test: "data" },
        decl_shapes: { some: "shape" },
        scope_plans: { plan: "data" },
        declarations: {}
      }

      result_state = run_pass(original_state)
      expect(result_state.to_h).to eq(original_state)
    end
  end
end