# frozen_string_literal: true

# This file registers test schemas at top-level where refinements work
# These schemas use the new Sugar syntax and can be tested via SugarTestHelper

require_relative "sugar_test_helper"

# Arithmetic operations schema
SugarTestHelper.register_schema(:arithmetic, Kumi.schema do
  input do
    float :a
    float :b
    integer :x
    integer :y
  end

  value :sum, input.a + input.b
  value :difference, input.a - input.b
  value :product, input.x * input.y
  value :quotient, input.a / input.b
  value :modulo, input.x % input.y
  value :power, input.x**input.y
  value :unary_minus, -input.a
end)

# Comparison operations schema
SugarTestHelper.register_schema(:comparison, Kumi.schema do
  input do
    integer :age
    float :score
  end

  trait :adult, input.age >= 18
  trait :minor, input.age < 18
  trait :teenager, input.age > 12
  trait :child, input.age <= 12
  trait :exact_age, input.age == 25
  trait :not_exact_age, input.age != 25
  trait :high_score, input.score >= 90.0
end)

# Literal lifting schema
SugarTestHelper.register_schema(:literal_lifting, Kumi.schema do
  input do
    float :value
    integer :count
  end

  # Integer literals on left side
  value :int_plus, 5 + input.count
  value :int_multiply, 3 * input.count

  # Float literals on left side
  value :float_plus, 5.5 + input.value
  value :float_multiply, 2.5 * input.value

  # Comparison with literals on left
  trait :int_greater, 10 > input.count
  trait :int_equal, 7 == input.count
  trait :float_equal, 7.5 == input.value
end)

# Bare identifier syntax schema
SugarTestHelper.register_schema(:bare_identifiers, Kumi.schema do
  input do
    float :income
    integer :age
  end

  # Base values
  value :base_income, input.income
  value :person_age, input.age

  # Bare identifier arithmetic (no ref() needed)
  value :net_income, base_income * 0.8
  value :double_age, person_age * 2

  # Bare identifier arrays and indexing
  value :scores, [100, 85, 92]
  value :first_score, scores[0]
  value :second_score, scores[1]

  # Bare identifier comparisons
  trait :high_income, base_income >= 50_000.0
  trait :adult, person_age >= 18

  # Bare identifier logical operations
  trait :wealthy_adult, high_income & adult
end)

# String operations schema
SugarTestHelper.register_schema(:string_ops, Kumi.schema do
  input do
    string :name
  end

  # String equality (only supported operation)
  trait :is_john, "John" == input.name
  trait :not_jane, "Jane" != input.name
  trait :inverted_check, input.name == "Alice"
end)

# Mixed chaining schema
SugarTestHelper.register_schema(:mixed_chaining, Kumi.schema do
  input do
    float :base_salary
    float :bonus_percent
    integer :years_experience
  end

  # Chained arithmetic with mixed literals and expressions
  value :bonus_amount, input.base_salary * (input.bonus_percent / 100.0)
  value :total_salary, input.base_salary + ref(:bonus_amount)

  # Chained comparisons
  trait :well_paid, ref(:total_salary) >= 80_000.0
  trait :experienced, input.years_experience > 5
  trait :senior_well_paid, well_paid & experienced
end)
