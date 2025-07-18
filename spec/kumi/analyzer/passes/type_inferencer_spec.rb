# frozen_string_literal: true

RSpec.describe Kumi::Analyzer::Passes::TypeInferencer do
  let(:schema) { instance_double("Schema") }
  let(:state) { {} }
  let(:errors) { [] }
  let(:pass) { described_class.new(schema, state) }

  describe "#run" do
    context "when decl_types already exists" do
      it "skips inference" do
        state[:decl_types] = { existing: :integer }

        pass.run(errors)

        expect(state[:decl_types]).to eq({ existing: :integer })
      end
    end

    context "with basic declarations" do
      let(:literal_expr) { Kumi::Syntax::TerminalExpressions::Literal.new(42) }
      let(:field_expr) { Kumi::Syntax::TerminalExpressions::FieldRef.new(:age) }
      let(:binding_expr) { Kumi::Syntax::TerminalExpressions::Binding.new(:other) }

      let(:literal_decl) { instance_double("Decl", expression: literal_expr, loc: nil) }
      let(:field_decl) { instance_double("Decl", expression: field_expr, loc: nil) }
      let(:binding_decl) { instance_double("Decl", expression: binding_expr, loc: nil) }

      before do
        state[:topo_order] = %i[literal_val field_val binding_val]
        state[:definitions] = {
          literal_val: literal_decl,
          field_val: field_decl,
          binding_val: binding_decl
        }
        state[:input_meta] = {
          age: { type: :integer, domain: nil }
        }
      end

      it "infers types for literals" do
        pass.run(errors)

        expect(state[:decl_types][:literal_val]).to eq(:integer)
      end

      it "uses annotated field types" do
        pass.run(errors)

        expect(state[:decl_types][:field_val]).to eq(:integer)
      end

      it "falls back to base type for unresolved bindings" do
        pass.run(errors)

        expect(state[:decl_types][:binding_val]).to eq(:any)
      end
    end

    context "with function calls" do
      let(:add_call) do
        Kumi::Syntax::Expressions::CallExpression.new(
          :add,
          [
            Kumi::Syntax::TerminalExpressions::Literal.new(1),
            Kumi::Syntax::TerminalExpressions::Literal.new(2)
          ]
        )
      end

      let(:comparison_call) do
        Kumi::Syntax::Expressions::CallExpression.new(
          :>,
          [
            Kumi::Syntax::TerminalExpressions::Literal.new(5),
            Kumi::Syntax::TerminalExpressions::Literal.new(3)
          ]
        )
      end

      let(:add_decl) { instance_double("Decl", expression: add_call, loc: nil) }
      let(:comp_decl) { instance_double("Decl", expression: comparison_call, loc: nil) }

      before do
        state[:topo_order] = %i[sum is_greater]
        state[:definitions] = {
          sum: add_decl,
          is_greater: comp_decl
        }
      end

      it "infers return types from function calls" do
        pass.run(errors)

        expect(state[:decl_types][:sum]).to eq(Kumi::Types::NUMERIC)
        expect(state[:decl_types][:is_greater]).to eq(Kumi::Types::BOOL)
      end
    end

    context "with list expressions" do
      let(:list_expr) do
        Kumi::Syntax::Expressions::ListExpression.new([
                                                        Kumi::Syntax::TerminalExpressions::Literal.new(1),
                                                        Kumi::Syntax::TerminalExpressions::Literal.new(2),
                                                        Kumi::Syntax::TerminalExpressions::Literal.new(3)
                                                      ])
      end

      let(:empty_list_expr) do
        Kumi::Syntax::Expressions::ListExpression.new([])
      end

      let(:list_decl) { instance_double("Decl", expression: list_expr, loc: nil) }
      let(:empty_list_decl) { instance_double("Decl", expression: empty_list_expr, loc: nil) }

      before do
        state[:topo_order] = %i[numbers empty]
        state[:definitions] = {
          numbers: list_decl,
          empty: empty_list_decl
        }
      end

      it "infers array types from list elements" do
        pass.run(errors)

        numbers_type = state[:decl_types][:numbers]
        expect(numbers_type).to eq({ array: :integer })
      end

      it "handles empty lists" do
        pass.run(errors)

        empty_type = state[:decl_types][:empty]
        expect(empty_type).to eq({ array: :any })
      end
    end

    context "with cascade expressions" do
      let(:case_expr) { Kumi::Syntax::Expressions::WhenCaseExpression.new(nil, Kumi::Syntax::TerminalExpressions::Literal.new("yes")) }
      let(:base_expr) { Kumi::Syntax::Expressions::WhenCaseExpression.new(nil, Kumi::Syntax::TerminalExpressions::Literal.new("no")) }

      let(:cascade_expr) do
        Kumi::Syntax::Expressions::CascadeExpression.new([case_expr, base_expr])
      end

      let(:cascade_decl) { instance_double("Decl", expression: cascade_expr, loc: nil) }

      before do
        state[:topo_order] = [:decision]
        state[:definitions] = { decision: cascade_decl }
      end

      it "unifies result types from all cases" do
        pass.run(errors)

        decision_type = state[:decl_types][:decision]
        expect(decision_type).to eq(Kumi::Types::STRING)
      end
    end

    context "with dependencies between declarations" do
      let(:binding_expr) { Kumi::Syntax::TerminalExpressions::Binding.new(:base_value) }
      let(:literal_expr) { Kumi::Syntax::TerminalExpressions::Literal.new(10) }

      let(:dependent_decl) { instance_double("Decl", expression: binding_expr, loc: nil) }
      let(:base_decl) { instance_double("Decl", expression: literal_expr, loc: nil) }

      before do
        state[:topo_order] = %i[base_value dependent_value]
        state[:definitions] = {
          base_value: base_decl,
          dependent_value: dependent_decl
        }
      end

      it "resolves dependencies in topological order" do
        pass.run(errors)

        expect(state[:decl_types][:base_value]).to eq(:integer)
        expect(state[:decl_types][:dependent_value]).to eq(:integer)
      end
    end

    context "error handling" do
      let(:error_decl) do
        decl = instance_double("Decl", loc: instance_double("Location"))
        allow(decl).to receive(:expression).and_raise(StandardError.new("test error"))
        decl
      end

      before do
        state[:topo_order] = [:error_val]
        state[:definitions] = { error_val: error_decl }
      end

      it "captures and reports inference errors" do
        pass.run(errors)

        expect(errors).not_to be_empty
        expect(errors.first[1]).to include("Type inference failed")
      end
    end
  end

  describe "private methods" do
    describe "#infer_expression_type" do
      it "handles unknown expression types" do
        unknown_expr = double("UnknownExpr")

        result = pass.send(:infer_expression_type, unknown_expr, {})

        expect(result).to eq(:any)
      end
    end
  end
end
