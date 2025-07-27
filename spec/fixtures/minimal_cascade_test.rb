#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/kumi"

module MinimalCascadeTest
  extend Kumi::Schema

  schema do
    input do
      string :status
      integer :age
      float :salary
    end

    # Non-conflicting string-based traits
    trait :single, input.status == "single"
    trait :married, input.status == "married"
    trait :divorced, input.status == "divorced"

    # Age traits that don't conflict when used individually
    trait :young, input.age < 30
    trait :middle, (input.age >= 30) & (input.age < 60)
    trait :senior, input.age >= 60

    # Test 1: String-based cascade (should work)
    value :tax_status do
      on single, "Single Filer"
      on married, "Married Filing Jointly"
      on divorced, "Head of Household"
      base "Status Unknown"
    end

    # Test 2: Age-based cascade with non-conflicting single traits (should work)
    value :age_group do
      on young, "Young Professional"
      on middle, "Mid-Career"
      on senior, "Senior Professional"
      base "Age Unknown"
    end

    # Test 3: Combination that should work (non-conflicting)
    trait :young_single, young & single
    trait :senior_married, senior & married

    value :demographic do
      on young_single, "Young Single Person"
      on senior_married, "Senior Married Person"
      base "Other Demographic"
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  puts "Testing minimal cascade scenarios..."

  # Test young single person
  runner = MinimalCascadeTest.from(status: "single", age: 25, salary: 50_000.0)
  puts "Young single: #{runner.slice(:tax_status, :age_group, :demographic)}"

  # Test senior married person
  runner = MinimalCascadeTest.from(status: "married", age: 65, salary: 80_000.0)
  puts "Senior married: #{runner.slice(:tax_status, :age_group, :demographic)}"

  puts "✅ All cascades working correctly!"
end
