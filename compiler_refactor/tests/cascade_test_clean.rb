#!/usr/bin/env ruby

require_relative "../ir_test_helper"

module CascadeExample
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      integer :age
      float :income
    end

    trait :is_adult, input.age >= 18
    trait :high_income, input.income > 50_000
    trait :fully_qualified, is_adult & high_income

    value :eligibility_status do
      on fully_qualified, "fully_eligible"
      on is_adult, "age_eligible"
      base "not_eligible"
    end

    value :discount_rate do
      on high_income, 0.0
      on is_adult, 0.10
      base 0.25
    end
  end
end

# Test different scenarios
test_cases = [
  {
    data: { age: 25, income: 75_000.0 },
    expected: {
      eligibility_status: "fully_eligible",
      discount_rate: 0.0
    }
  },
  {
    data: { age: 20, income: 30_000.0 },
    expected: {
      eligibility_status: "age_eligible",
      discount_rate: 0.10
    }
  },
  {
    data: { age: 16, income: 0.0 },
    expected: {
      eligibility_status: "not_eligible",
      discount_rate: 0.25
    }
  }
]

puts "Testing CascadeExample Schema"
puts "=" * 50

test_cases.each_with_index do |test_case, i|
  puts "\nTest Case #{i + 1}: age=#{test_case[:data][:age]}, income=#{test_case[:data][:income]}"
  results = IRTestHelper.run_test(CascadeExample, test_case[:data], test_case[:expected], debug: false)

  results.each do |key, value|
    status = value == test_case[:expected][key] ? "✓" : "✗"
    puts "  #{status} #{key}: #{value}"
  end
end
