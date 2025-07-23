# Kumi 

[![CI](https://github.com/amuta/kumi/workflows/CI/badge.svg)](https://github.com/amuta/kumi/actions)
[![Gem Version](https://badge.fury.io/rb/kumi.svg)](https://badge.fury.io/rb/kumi)

Kumi is a declarative rule‑and‑calculation DSL for Ruby that turns scattered business logic into a statically‑checked dependency graph.

Every input, trait, and formula is compiled into a typed AST node, so the entire graph is explicit and introspectable.

Note: The examples here are small for the sake of readability. I would not recommend using this gem unless you need to keep track of 100+ conditions/variables.


## How to get started

Install Kumi and try running the examples below or explore the `./examples` directory of this repository.
```
gem install kumi
```

## Example

**Instead of scattered logic:**
```ruby
def calculate_loan_approval(credit_score, income, debt_ratio)
  good_credit = credit_score >= 700
  sufficient_income = income >= 50_000  
  low_debt = debt_ratio <= 0.3
  
  if good_credit && sufficient_income && low_debt
    { approved: true, rate: 3.5 }
  else
    { approved: false, rate: nil }
  end
end
```

**You can write:**
```ruby
module LoanApproval
  extend Kumi::Schema

  schema do
    input do
      integer :credit_score
      float :income
      float :debt_to_income_ratio
    end

    trait :good_credit, input.credit_score >= 700
    trait :sufficient_income, input.income >= 50_000
    trait :low_debt, input.debt_to_income_ratio <= 0.3
    trait :approved, good_credit & sufficient_income & low_debt
    
    value :interest_rate do
      on :approved, 3.5
      base 0.0
    end
  end
end

runner = LoanApproval.from(credit_score: 750, income: 60_000, debt_to_income_ratio: 0.25)
puts runner[:approved]       # => true
puts runner[:interest_rate]  # => 3.5
```

This gets you:
- Static analysis catches impossible logic combinations at compile time
- Automatic dependency tracking prevents circular references  
- Type safety with domain constraints (age: 0..150, status: %w[active inactive])
- Microsecond performance not much different than optimized pure ruby
- Introspectable - see exactly how any value was computed

## Static Analysis & Safety

Kumi analyzes your rules to catch logical impossibilities:

```ruby
module ImpossibleLogic
  extend Kumi::Schema

  schema do
    input {}  # No inputs needed

    value :x, 100
    trait :x_less_than_100, x < 100        # false: 100 < 100
    
    value :y, x * 10                       # 1000  
    trait :y_greater_than_1000, y > 1000   # false: 1000 > 1000

    value :result do
      # This is impossible
      on :x_less_than_100 & :y_greater_than_1000, "Impossible!"
      base "Default"
    end
  end
end

# Kumi::Errors::SemanticError: conjunction `x_less_than_100 AND y_greater_than_1000` is impossible
```

Cycle detection:
```ruby
module CircularDependency
  extend Kumi::Schema

  schema do
    input { float :base }

    # These create a circular dependency
    value :monthly_rate, yearly_rate / 12
    value :yearly_rate, monthly_rate * 12
  end
end

# Kumi::Errors::SemanticError: cycle detected involving: monthly_rate → yearly_rate → monthly_rate
```

## Performance

Kumi has microsecond evaluation times through automatic memoization:

### Deep Dependency Chains
```
=== Evaluation Performance (with Memoization) ===
eval  50-deep:  817,497 i/s  (1.22 μs/i)
eval 100-deep:  509,567 i/s  (1.96 μs/i) 
eval 150-deep:  376,429 i/s  (2.66 μs/i)
eval 200-deep:  282,243 i/s  (3.54 μs/i)
```

### Wide Complex Schemas  
```
=== Evaluation Performance (with Memoization) ===
eval  1,000-wide:  127,652 i/s  (7.83 μs/i)
eval  5,000-wide:   26,604 i/s  (37.59 μs/i) 
eval 10,000-wide:   13,670 i/s  (73.15 μs/i)
```

Here's how the memoization works:
```ruby
module ProductPricing
  extend Kumi::Schema
  
  schema do
    input do
      float :base_price
      float :tax_rate
      integer :quantity
    end
    
    value :unit_price_with_tax, input.base_price * (1 + input.tax_rate)
    value :total_before_discount, unit_price_with_tax * input.quantity
    value :bulk_discount, input.quantity >= 10 ? 0.1 : 0.0
    value :final_total, total_before_discount * (1 - bulk_discount)
  end
end

runner = ProductPricing.from(base_price: 100.0, tax_rate: 0.08, quantity: 15)

# First access: computes and caches all intermediate values
puts runner[:final_total]           # => 1458.0 (computed + cached)

# Subsequent accesses: pure cache lookups (microsecond performance)
puts runner[:unit_price_with_tax]   # => 108.0 (from cache)
puts runner[:bulk_discount]         # => 0.1 (from cache) 
puts runner[:final_total]           # => 1458.0 (from cache)
```

Architecture notes:
- Compile-once, evaluate-many: Schema compilation happens once, evaluations are pure computation
- `EvaluationWrapper` caches computed values automatically for subsequent access
- Stack-safe algorithms: Iterative cycle detection and dependency resolution prevent stack overflow
- Type-safe execution: No runtime type checking overhead after compilation

## DSL Features

### Domain Constraints
```ruby
module UserProfile
  extend Kumi::Schema

  schema do
    input do
      integer :age, domain: 0..150
      string :status, domain: %w[active inactive suspended]
      float :score, domain: 0.0..100.0
    end

    trait :adult, input.age >= 18
    trait :active_user, input.status == "active"
  end
end

# Valid data works fine
UserProfile.from(age: 25, status: "active", score: 85.5)

# Invalid data raises detailed errors
UserProfile.from(age: 200, status: "invalid", score: -10)
# => Kumi::Errors::DomainViolationError: Domain constraint violations...
```

### Cascade Logic
```ruby
module ShippingCost
  extend Kumi::Schema

  schema do
    input do
      float :order_total
      string :membership_level
    end

    trait :premium_member, input.membership_level == "premium"
    trait :large_order, input.order_total >= 100

    value :shipping_cost do
      on :premium_member, 0.0
      on :large_order, 5.0
      base 15.0
    end
  end
end

runner = ShippingCost.from(order_total: 75, membership_level: "standard")
puts runner[:shipping_cost]  # => 15.0
```

### Functions
```ruby
module Statistics
  extend Kumi::Schema

  schema do
    input do
      array :scores, elem: { type: :float }
    end

    value :total, fn(:sum, input.scores)
    value :count, fn(:size, input.scores)
    value :average, total / count
    value :max_score, fn(:max, input.scores)
  end
end

runner = Statistics.from(scores: [85.5, 92.0, 78.5, 96.0])
puts runner[:average]    # => 88.0
puts runner[:max_score]  # => 96.0
```

## Introspection

You can see exactly how any value was computed:

```ruby
module TaxCalculator
  extend Kumi::Schema

  schema do
    input do
      float :income
      float :tax_rate
      float :deductions
    end

    value :taxable_income, input.income - input.deductions
    value :tax_amount, taxable_income * input.tax_rate
  end
end

inputs = { income: 100_000, tax_rate: 0.25, deductions: 12_000 }

puts Kumi::Explain.call(TaxCalculator, :taxable_income, inputs: inputs)
# => taxable_income = input.income - deductions = (input.income = 100 000) - (deductions = 12 000) => 88 000

puts Kumi::Explain.call(TaxCalculator, :tax_amount, inputs: inputs)  
# => tax_amount = taxable_income × input.tax_rate = (taxable_income = 88 000) × (input.tax_rate = 0.25) => 22 000
```

## Try It Yourself

Run the performance benchmarks:
```bash
bundle exec ruby examples/wide_schema_compilation_and_evaluation_benchmark.rb
bundle exec ruby examples/deep_schema_compilation_and_evaluation_benchmark.rb
```

## DSL Syntax Reference

See [`documents/SYNTAX.md`](documents/SYNTAX.md) for complete syntax documentation with sugar vs sugar-free examples.