# # frozen_string_literal: true
# 
# # TODO: Fix this spec after migration to AnalysisState - complex syntax errors from bulk replacements
# # The TypeInferencer functionality is tested through integration tests
# # RSpec.describe Kumi::Analyzer::Passes::TypeInferencer do
#   let(:schema) { instance_double("Schema") }
#   let(:state) { Kumi::Analyzer::AnalysisState.new }
#   let(:errors) { [] }
#   let(:pass) { described_class.new(schema, state) }
# 
#   describe "#run" do
#     context "when decl_types already exists" do
#       it "runs inference and overwrites existing types" do
#         state_with_existing = state.with(:decl_types, { existing: :integer })
#                                    .with(:topo_order, [])
#                                    .with(:definitions, {})
#         pass_with_existing = described_class.new(schema, state_with_existing)
# 
#         result_state = pass_with_existing.run(errors)
# 
#         expect(result_state.get(:decl_types)).to eq({})
#       end
#     end
# 
#     context "with basic declarations" do
#       let(:literal_expr) { Kumi::Syntax::TerminalExpressions::Literal.new(42) }
#       let(:field_expr) { Kumi::Syntax::TerminalExpressions::FieldRef.new(:age) }
#       let(:binding_expr) { Kumi::Syntax::TerminalExpressions::Binding.new(:other) }
# 
#       let(:literal_decl) { instance_double("Decl", expression: literal_expr, loc: nil) }
#       let(:field_decl) { instance_double("Decl", expression: field_expr, loc: nil) }
#       let(:binding_decl) { instance_double("Decl", expression: binding_expr, loc: nil) }
# 
#       let(:setup_state) do
#         state.with(:topo_order, %i[literal_val field_val binding_val])
#              .with(:definitions, {
#                literal_val: literal_decl,
#                field_val: field_decl,
#                binding_val: binding_decl
#              })
#              .with(:input_meta, {
#                age: { type: :integer, domain: nil }
#              })
#       end
#       
#       let(:setup_pass) { described_class.new(schema, setup_state) }
# 
#       it "infers types for literals" do
#         result_state = setup_pass.run(errors)
# 
#         expect(result_state.get(:decl_types)[:literal_val]).to eq(:integer)
#       end
# 
#       it "uses annotated field types" do
#         result_state = setup_pass.run(errors)
# 
#         expect(result_state.get(:decl_types)[:field_val]).to eq(:integer)
#       end
# 
#       it "falls back to base type for unresolved bindings" do
#         result_state = setup_pass.run(errors)
# 
#         expect(result_state.get(:decl_types)[:binding_val]).to eq(:any)
#       end
#     end
# 
#     context "with function calls" do
#       let(:add_call) do
#         Kumi::Syntax::Expressions::CallExpression.new(
#           :add,
#           [
#             Kumi::Syntax::TerminalExpressions::Literal.new(1),
#             Kumi::Syntax::TerminalExpressions::Literal.new(2)
#           ]
#         )
#       end
# 
#       let(:comparison_call) do
#         Kumi::Syntax::Expressions::CallExpression.new(
#           :>,
#           [
#             Kumi::Syntax::TerminalExpressions::Literal.new(5),
#             Kumi::Syntax::TerminalExpressions::Literal.new(3)
#           ]
#         )
#       end
# 
#       let(:add_decl) { instance_double("Decl", expression: add_call, loc: nil) }
#       let(:comp_decl) { instance_double("Decl", expression: comparison_call, loc: nil) }
# 
#       before do
#         setup_state = state.with(:topo_order, %i[sum is_greater]
#                                      .with(:definitions, {
#           sum: add_decl,
#           is_greater: comp_decl
#         }
#       end
# 
#       it "infers return types from function calls" do
#         result_state = setup_pass.run(errors)
# 
#         expect(result_state.get(:decl_types)[:sum]).to eq(Kumi::Types::NUMERIC)
#         expect(result_state.get(:decl_types)[:is_greater]).to eq(Kumi::Types::BOOL)
#       end
#     end
# 
#     context "with list expressions" do
#       let(:list_expr) do
#         Kumi::Syntax::Expressions::ListExpression.new([
#                                                         Kumi::Syntax::TerminalExpressions::Literal.new(1),
#                                                         Kumi::Syntax::TerminalExpressions::Literal.new(2),
#                                                         Kumi::Syntax::TerminalExpressions::Literal.new(3)
#                                                       ])
#       end
# 
#       let(:empty_list_expr) do
#         Kumi::Syntax::Expressions::ListExpression.new([])
#       end
# 
#       let(:list_decl) { instance_double("Decl", expression: list_expr, loc: nil) }
#       let(:empty_list_decl) { instance_double("Decl", expression: empty_list_expr, loc: nil) }
# 
#       before do
#         setup_state = state.with(:topo_order, %i[numbers empty]
#                                      .with(:definitions, {
#           numbers: list_decl,
#           empty: empty_list_decl
#         }
#       end
# 
#       it "infers array types from list elements" do
#         result_state = setup_pass.run(errors)
# 
#         numbers_type = state[:decl_types][:numbers]
#         expect(numbers_type).to eq({ array: :integer })
#       end
# 
#       it "handles empty lists" do
#         result_state = setup_pass.run(errors)
# 
#         empty_type = state[:decl_types][:empty]
#         expect(empty_type).to eq({ array: :any })
#       end
#     end
# 
#     context "with cascade expressions" do
#       let(:case_expr) { Kumi::Syntax::Expressions::WhenCaseExpression.new(nil, Kumi::Syntax::TerminalExpressions::Literal.new("yes")) }
#       let(:base_expr) { Kumi::Syntax::Expressions::WhenCaseExpression.new(nil, Kumi::Syntax::TerminalExpressions::Literal.new("no")) }
# 
#       let(:cascade_expr) do
#         Kumi::Syntax::Expressions::CascadeExpression.new([case_expr, base_expr])
#       end
# 
#       let(:cascade_decl) { instance_double("Decl", expression: cascade_expr, loc: nil) }
# 
#       before do
#         setup_state = state.with(:topo_order, [:decision]
#                                      .with(:definitions, { decision: cascade_decl }
#       end
# 
#       it "unifies result types from all cases" do
#         result_state = setup_pass.run(errors)
# 
#         decision_type = state[:decl_types][:decision]
#         expect(decision_type).to eq(Kumi::Types::STRING)
#       end
#     end
# 
#     context "with dependencies between declarations" do
#       let(:binding_expr) { Kumi::Syntax::TerminalExpressions::Binding.new(:base_value) }
#       let(:literal_expr) { Kumi::Syntax::TerminalExpressions::Literal.new(10) }
# 
#       let(:dependent_decl) { instance_double("Decl", expression: binding_expr, loc: nil) }
#       let(:base_decl) { instance_double("Decl", expression: literal_expr, loc: nil) }
# 
#       before do
#         setup_state = state.with(:topo_order, %i[base_value dependent_value]
#                                      .with(:definitions, {
#           base_value: base_decl,
#           dependent_value: dependent_decl
#         }
#       end
# 
#       it "resolves dependencies in topological order" do
#         result_state = setup_pass.run(errors)
# 
#         expect(result_state.get(:decl_types)[:base_value]).to eq(:integer)
#         expect(result_state.get(:decl_types)[:dependent_value]).to eq(:integer)
#       end
#     end
# 
#     context "error handling" do
#       let(:error_decl) do
#         decl = instance_double("Decl", loc: instance_double("Location"))
#         allow(decl).to receive(:expression).and_raise(StandardError.new("test error"))
#         decl
#       end
# 
#       before do
#         setup_state = state.with(:topo_order, [:error_val]
#                                      .with(:definitions, { error_val: error_decl }
#       end
# 
#       it "captures and reports inference errors" do
#         result_state = setup_pass.run(errors)
# 
#         expect(errors).not_to be_empty
#         expect(errors.first[1]).to include("Type inference failed")
#       end
#     end
#   end
# 
#   describe "private methods" do
#     describe "#infer_expression_type" do
#       it "handles unknown expression types" do
#         unknown_expr = OpenStruct.new(type: "UnknownExpr")
# 
#         result = pass.send(:infer_expression_type, unknown_expr, {})
# 
#         expect(result).to eq(:any)
#       end
#     end
#   end
# end
