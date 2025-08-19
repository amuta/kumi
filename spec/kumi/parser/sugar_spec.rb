# # frozen_string_literal: true

# require "spec_helper"

# # Load all the sugar schema modules
# require_relative "../sugar_arithmetic_spec"
# require_relative "../sugar_comparison_spec"
# require_relative "../sugar_literal_lifting_spec"
# require_relative "../sugar_bare_identifiers_spec"
# require_relative "../sugar_string_ops_spec"
# require_relative "../sugar_mixed_chaining_spec"

# RSpec.describe "Kumi::Core::RubyParser::Sugar" do
#   describe "arithmetic operators on expressions" do
#     it "creates correct CallExpression nodes for arithmetic operators" do
#       runner = ArithmeticSugar.from(a: 10.0, b: 3.0, x: 7, y: 2)

#       expect(runner[:sum]).to eq(13.0)
#       expect(runner[:difference]).to eq(7.0)
#       expect(runner[:product]).to eq(14)
#       expect(runner[:quotient]).to be_within(0.001).of(3.333)
#       expect(runner[:modulo]).to eq(1)
#       expect(runner[:power]).to eq(49)
#       expect(runner[:unary_minus]).to eq(-10.0)
#     end
#   end

#   describe "comparison operators on expressions" do
#     it "creates correct CallExpression nodes for comparison operators" do
#       runner = ComparisonSugar.from(age: 25, score: 95.5)

#       expect(runner[:adult]).to be true
#       expect(runner[:minor]).to be false
#       expect(runner[:teenager]).to be true
#       expect(runner[:child]).to be false
#       expect(runner[:exact_age]).to be true
#       expect(runner[:not_exact_age]).to be false
#       expect(runner[:high_score]).to be true
#     end
#   end

#   describe "literal lifting - numeric operators" do
#     it "automatically lifts numeric literals to Literal nodes" do
#       runner = LiteralLiftingSugar.from(value: 7.5, count: 7)

#       # Integer arithmetic
#       expect(runner[:int_plus]).to eq(12)
#       expect(runner[:int_multiply]).to eq(21)

#       # Float arithmetic
#       expect(runner[:float_plus]).to eq(13.0)
#       expect(runner[:float_multiply]).to eq(18.75)

#       # Comparisons (10 > 7 should be true, not false)
#       expect(runner[:int_greater]).to be true
#       expect(runner[:int_equal]).to be true
#       expect(runner[:float_equal]).to be true
#     end
#   end

#   describe "bare identifier syntax" do
#     it "supports operators on bare identifiers without ref()" do
#       runner = BareIdentifiersSugar.from(income: 75_000.0, age: 30)

#       expect(runner[:net_income]).to eq(60_000.0)
#       expect(runner[:double_age]).to eq(60)

#       expect(runner[:first_score]).to eq(100)
#       expect(runner[:second_score]).to eq(85)

#       expect(runner[:high_income]).to be true
#       expect(runner[:adult]).to be true
#       expect(runner[:wealthy_adult]).to be true
#     end
#   end

#   describe "string operations" do
#     it "supports string equality operations" do
#       runner = StringOpsSugar.from(name: "John")

#       expect(runner[:is_john]).to be true
#       expect(runner[:not_jane]).to be true
#       expect(runner[:inverted_check]).to be false
#     end
#   end

#   describe "mixed expression chaining" do
#     it "handles complex expression chaining correctly" do
#       runner = MixedChainingSugar.from(base_salary: 70_000.0, bonus_percent: 15.0, years_experience: 8)

#       expect(runner[:bonus_amount]).to eq(10_500.0)
#       expect(runner[:total_salary]).to eq(80_500.0)

#       expect(runner[:well_paid]).to be true
#       expect(runner[:experienced]).to be true
#       expect(runner[:senior_well_paid]).to be true
#     end
#   end

#   describe "edge cases and error handling" do
#     it "preserves normal Ruby behavior for non-Expression operations" do
#       # Normal Ruby operations should work unchanged
#       expect(5 + 3).to eq(8)
#       actual_string = "hello world"
#       expect(actual_string).to eq("hello world")
#       expect(10 > 5).to be true
#     end

#     it "only activates refinements when expressions are involved" do
#       # These should use normal Ruby behavior, not create CallExpressions
#       result = 10 + 5
#       expect(result).to be_a(Integer)
#       expect(result).to eq(15)

#       string_result = "testing"
#       expect(string_result).to be_a(String)
#       expect(string_result).to eq("testing")
#     end
#   end
# end
