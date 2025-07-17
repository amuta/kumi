#!/usr/bin/env ruby
# frozen_string_literal: true

# Input Block Typing Showcase
# This example demonstrates the new input block feature with explicit typing,
# showing how declared types and inferred types work together in Kumi.

require_relative '../lib/kumi'

puts "🎯 Kumi Input Block Typing Showcase"
puts "=" * 50

# Example 1: Basic Input Block with Type Declarations
puts "\n📝 Example 1: Basic Input Block with Type Declarations"
puts "-" * 50

begin
  employee_assessment = Kumi.schema do
    input do
      key :name, type: Kumi::Types::STRING
      key :age, type: Kumi::Types::INT, domain: 18..65
      key :years_experience, type: Kumi::Types::INT, domain: 0..40
      key :salary, type: Kumi::Types::FLOAT, domain: 30_000.0..200_000.0
      key :department, type: Kumi::Types::STRING
      key :is_remote, type: Kumi::Types::BOOL
    end

    # Predicates using declared input types
    predicate :is_senior, input.years_experience, :>=, 5
    predicate :is_well_paid, input.salary, :>, 80_000.0
    predicate :is_tech_dept, input.department, :==, "Engineering"

    # Values with inferred types based on expressions
    value :seniority_level, fn(:conditional, 
      fn(:>=, input.years_experience, 10), "Senior",
      fn(:conditional, 
        fn(:>=, input.years_experience, 5), "Mid-level",
        fn(:conditional, 
          fn(:>=, input.years_experience, 2), "Junior",
          "Entry-level"
        )
      )
    )

    value :total_comp_estimate, fn(:multiply, input.salary, 1.15) # Benefits factor
    value :profile_summary, fn(:concat, 
      input.name, " (", input.age, " years old) - ", 
      ref(:seniority_level), " ", input.department
    )
  end

  puts "✅ Schema compiled successfully!"
  
  # Show type information
  puts "\n📊 Type Information:"
  puts "Input Types (Declared):"
  employee_assessment.analysis.state[:input_meta].each do |field, meta|
    domain_info = meta[:domain] ? " (domain: #{meta[:domain]})" : ""
    puts "  #{field}: #{meta[:type]}#{domain_info}"
  end

  puts "\nInferred Types:"
  employee_assessment.analysis.decl_types.each do |name, type|
    puts "  #{name}: #{type}"
  end

  # Test with sample data
  puts "\n🧪 Testing with Sample Data:"
  sample_data = {
    name: "Alice Johnson",
    age: 32,
    years_experience: 8,
    salary: 95_000.0,
    department: "Engineering",
    is_remote: true
  }

  runner = Kumi.from(sample_data)
  result = {
    is_senior: runner.fetch(:is_senior),
    is_well_paid: runner.fetch(:is_well_paid),
    is_tech_dept: runner.fetch(:is_tech_dept),
    seniority_level: runner.fetch(:seniority_level),
    total_comp_estimate: runner.fetch(:total_comp_estimate),
    profile_summary: runner.fetch(:profile_summary)
  }

  puts "Results: #{result}"

rescue => e
  puts "❌ Error: #{e.message}"
end

# Example 2: Type Validation in Action
puts "\n\n🔍 Example 2: Type Validation in Action"
puts "-" * 50

puts "Attempting to create a schema with type mismatches..."

begin
  invalid_schema = Kumi.schema do
    input do
      key :age, type: Kumi::Types::INT
      key :name, type: Kumi::Types::STRING
    end

    # This should fail: trying to use STRING in numeric addition
    value :invalid_calc, fn(:add, input.name, 10)
  end

  puts "❌ Schema should have failed but didn't!"
rescue => e
  puts "✅ Correctly caught type error:"
  puts "   #{e.message}"
end

# Example 3: Array Type Compatibility
puts "\n\n📋 Example 3: Array Type Compatibility"
puts "-" * 50

begin
  data_processor = Kumi.schema do
    input do
      key :scores, type: Kumi::Types.array(Kumi::Types::INT)
      key :weights, type: Kumi::Types.array(Kumi::Types::FLOAT)
    end

    # These should work due to array type compatibility
    value :total_score, fn(:sum, input.scores)          # array<int> compatible with array<numeric>
    value :first_weight, fn(:first, input.weights)      # array<float> compatible with array<any>
    value :score_size, fn(:size, input.scores)          # array<int> compatible with array<any>
    
    # Complex calculation using both arrays
    value :weighted_score, fn(:multiply, 
      ref(:total_score), 
      ref(:first_weight)
    )
  end

  puts "✅ Array type compatibility working correctly!"
  
  # Test with data
  array_data = {
    scores: [85, 92, 78, 95, 88],
    weights: [0.3, 0.4, 0.2, 0.1]
  }

  runner = Kumi.from(array_data)
  puts "Results:"
  puts "  Total Score: #{runner.fetch(:total_score)}"
  puts "  First Weight: #{runner.fetch(:first_weight)}"
  puts "  Score Size: #{runner.fetch(:score_size)}"
  puts "  Weighted Score: #{runner.fetch(:weighted_score)}"

rescue => e
  puts "❌ Error: #{e.message}"
end

# Example 4: Domain Validation
puts "\n\n🎯 Example 4: Enhanced Error Messages with Type Information"
puts "-" * 50

begin
  grade_processor = Kumi.schema do
    input do
      key :score, type: Kumi::Types::INT
      key :assignment_weight, type: Kumi::Types::FLOAT
    end

    # Try to use score in an incompatible operation
    value :invalid_grade, fn(:add, input.score, "not a number")
  end

  puts "❌ Should have failed with type mismatch!"
rescue => e
  puts "✅ Enhanced error message with type information:"
  puts "   #{e.message}"
end

# Example 5: Complex Business Logic with Mixed Types
puts "\n\n💼 Example 5: Complex Business Logic with Mixed Types"
puts "-" * 50

begin
  loan_approval = Kumi.schema do
    input do
      key :applicant_name, type: Kumi::Types::STRING
      key :age, type: Kumi::Types::INT, domain: 18..80
      key :annual_income, type: Kumi::Types::FLOAT, domain: 0.0..1_000_000.0
      key :credit_score, type: Kumi::Types::INT, domain: 300..850
      key :employment_years, type: Kumi::Types::INT, domain: 0..50
      key :loan_amount, type: Kumi::Types::FLOAT, domain: 1_000.0..500_000.0
      key :has_collateral, type: Kumi::Types::BOOL
    end

    # Risk assessment predicates
    predicate :good_credit, input.credit_score, :>=, 650
    predicate :stable_employment, input.employment_years, :>=, 2
    predicate :reasonable_income, input.annual_income, :>=, 30_000.0
    predicate :mature_age, input.age, :>=, 25

    # Calculated values with inferred types
    value :debt_to_income_ratio, fn(:divide, input.loan_amount, input.annual_income)
    value :risk_score, fn(:multiply, 
      fn(:conditional, ref(:good_credit), 0.3, 0.7),
      fn(:conditional, ref(:stable_employment), 0.8, 1.2)
    )

    # Complex approval logic
    value :approval_status, fn(:conditional, 
      fn(:and, fn(:and, ref(:good_credit), ref(:stable_employment)), ref(:reasonable_income)), "Pre-Approved",
      fn(:conditional, 
        fn(:and, ref(:mature_age), input.has_collateral), "Conditional Approval",
        fn(:conditional, 
          fn(:and, ref(:reasonable_income), fn(:<, ref(:debt_to_income_ratio), 0.4)), "Under Review",
          "Declined"
        )
      )
    )

    value :approval_summary, fn(:concat,
      "Loan Application for ", input.applicant_name, ": ",
      ref(:approval_status), " (Risk Score: ", ref(:risk_score), ")"
    )
  end

  puts "✅ Complex business logic schema compiled successfully!"
  
  # Test with sample loan application
  loan_data = {
    applicant_name: "John Doe",
    age: 35,
    annual_income: 75_000.0,
    credit_score: 720,
    employment_years: 5,
    loan_amount: 200_000.0,
    has_collateral: true
  }

  runner = Kumi.from(loan_data)
  puts "\n📊 Loan Application Results:"
  puts "  Debt-to-Income Ratio: #{runner.fetch(:debt_to_income_ratio).round(3)}"
  puts "  Risk Score: #{runner.fetch(:risk_score).round(3)}"
  puts "  Approval Status: #{runner.fetch(:approval_status)}"
  puts "  Summary: #{runner.fetch(:approval_summary)}"

rescue => e
  puts "❌ Error: #{e.message}"
end

# Summary
puts "\n\n🎉 Summary of Input Block Typing Features"
puts "=" * 50
puts "✅ Explicit type declarations in input blocks"
puts "✅ Clear separation between declared and inferred types"
puts "✅ Enhanced error messages showing type provenance"
puts "✅ Array, set, and hash type compatibility"
puts "✅ Complex business logic with mixed type operations"
puts "✅ Runtime type safety with compile-time validation"
puts "✅ Input field references with input.field_name syntax"
puts "\nThe new input block feature provides a robust foundation for"
puts "type-safe decision modeling in Kumi! 🚀"