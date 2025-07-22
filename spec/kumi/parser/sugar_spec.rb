# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Kumi::Parser::Sugar" do
  describe "arithmetic operators on expressions" do
    it "creates correct CallExpression nodes for arithmetic operators" do
      runner = run_sugar_schema(:arithmetic, a: 10.0, b: 3.0, x: 7, y: 2)

      expect(runner.fetch(:sum)).to eq(13.0)
      expect(runner.fetch(:difference)).to eq(7.0)
      expect(runner.fetch(:product)).to eq(14)
      expect(runner.fetch(:quotient)).to be_within(0.001).of(3.333)
      expect(runner.fetch(:modulo)).to eq(1)
      expect(runner.fetch(:power)).to eq(49)
      expect(runner.fetch(:unary_minus)).to eq(-10.0)
    end
  end

  describe "comparison operators on expressions" do
    it "creates correct CallExpression nodes for comparison operators" do
      runner = run_sugar_schema(:comparison, age: 25, score: 95.5)

      expect(runner.fetch(:adult)).to be true
      expect(runner.fetch(:minor)).to be false
      expect(runner.fetch(:teenager)).to be true
      expect(runner.fetch(:child)).to be false
      expect(runner.fetch(:exact_age)).to be true
      expect(runner.fetch(:not_exact_age)).to be false
      expect(runner.fetch(:high_score)).to be true
    end
  end

  describe "literal lifting - numeric operators" do
    it "automatically lifts numeric literals to Literal nodes" do
      runner = run_sugar_schema(:literal_lifting, value: 7.5, count: 7)

      # Integer arithmetic
      expect(runner.fetch(:int_plus)).to eq(12)
      expect(runner.fetch(:int_multiply)).to eq(21)

      # Float arithmetic
      expect(runner.fetch(:float_plus)).to eq(13.0)
      expect(runner.fetch(:float_multiply)).to eq(18.75)

      # Comparisons (10 > 7 should be true, not false)
      expect(runner.fetch(:int_greater)).to be true
      expect(runner.fetch(:int_equal)).to be true
      expect(runner.fetch(:float_equal)).to be true
    end
  end

  describe "bare identifier syntax" do
    it "supports operators on bare identifiers without ref()" do
      runner = run_sugar_schema(:bare_identifiers, income: 75000.0, age: 30)

      expect(runner.fetch(:net_income)).to eq(60000.0)
      expect(runner.fetch(:double_age)).to eq(60)

      expect(runner.fetch(:first_score)).to eq(100)
      expect(runner.fetch(:second_score)).to eq(85)

      expect(runner.fetch(:high_income)).to be true
      expect(runner.fetch(:adult)).to be true
      expect(runner.fetch(:wealthy_adult)).to be true
    end
  end

  describe "string operations" do
    it "supports string equality operations" do
      runner = run_sugar_schema(:string_ops, name: "John")

      expect(runner.fetch(:is_john)).to be true
      expect(runner.fetch(:not_jane)).to be true
      expect(runner.fetch(:inverted_check)).to be false
    end
  end

  describe "mixed expression chaining" do
    it "handles complex expression chaining correctly" do
      runner = run_sugar_schema(:mixed_chaining, base_salary: 70000.0, bonus_percent: 15.0, years_experience: 8)

      expect(runner.fetch(:bonus_amount)).to eq(10500.0)
      expect(runner.fetch(:total_salary)).to eq(80500.0)

      expect(runner.fetch(:well_paid)).to be true
      expect(runner.fetch(:experienced)).to be true
      expect(runner.fetch(:senior_well_paid)).to be true
    end
  end

  describe "edge cases and error handling" do
    it "preserves normal Ruby behavior for non-Expression operations" do
      # Normal Ruby operations should work unchanged
      expect(5 + 3).to eq(8)
      expect("hello" + " world").to eq("hello world")
      expect(10 > 5).to be true
    end

    it "only activates refinements when expressions are involved" do
      # These should use normal Ruby behavior, not create CallExpressions
      result = 10 + 5
      expect(result).to be_a(Integer)
      expect(result).to eq(15)

      string_result = "test" + "ing"
      expect(string_result).to be_a(String)
      expect(string_result).to eq("testing")
    end
  end
end