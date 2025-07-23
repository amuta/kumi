# Kumi 

Kumi is a declarative rule‑and‑calculation DSL for Ruby that turns scattered business logic into a statically‑checked dependency graph.

Every input, trait, and formula is compiled into a typed AST node, so the entire graph is explicit and introspectable.

## Explain

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

## Traits

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
  end
end

runner = LoanApproval.from(credit_score: 750, income: 60_000, debt_to_income_ratio: 0.25)
puts runner[:approved]  # => true
```

## Domain Constraints

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

## Cascade Logic

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

## Functions

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

## Static Analysis

```ruby
module DeepAnalysis
  extend Kumi::Schema

  schema do
    input do
      # No inputs needed - uses constants
    end

    value :x, 100
    trait :x_lt_100, x < 100          # false: 100 < 100
    
    value :y, x * 10                  # 1000  
    trait :y_gt_1000, y > 1000        # false: 1000 > 1000

    value :result do
      # ❌ Kumi reasons: x=100 → x<100 is false, y=1000 → y>1000 is false
      on :x_lt_100, :y_gt_1000, "Impossible combination"
      base "Default"
    end
  end
end

# Kumi::Errors::SemanticError: conjunction `x_lt_100 AND y_gt_1000` is logically impossible  
# Catches contradictions through transitive mathematical reasoning
```

## Cycle Detection

```ruby
module CircularDependency
  extend Kumi::Schema

  schema do
    input do
      float :base_value
    end

    # ❌ These create a circular dependency
    value :monthly_rate, yearly_rate / 12
    value :yearly_rate, monthly_rate * 12
    
    # ❌ More complex cycle  
    value :a, b + input.base_value
    value :b, c * 2
    value :c, d - 1  
    value :d, a / 4
  end
end

# Kumi::Errors::SemanticError: cycle detected involving: monthly_rate → yearly_rate → monthly_rate
# Catches impossible dependency loops at compile time
```

## Performance

Kumi is designed for high-performance evaluation of complex business rules with efficient compilation and optimized execution.

### Wide Schema Benchmark

The `examples/wide_schema_compilation_and_evaluation_benchmark.rb` demonstrates Kumi's scalability with increasingly complex schemas:

```
=== Compilation Times ===
compile  1,000-wide:   39.6 ms
compile  5,000-wide:  128.1 ms
compile 10,000-wide:  371.6 ms

=== Evaluation Performance ===
eval  1,000-wide:  1,048.9 i/s  (953 μs/i)
eval  5,000-wide:    199.3 i/s  (5.02 ms/i) 
eval 10,000-wide:     92.3 i/s  (10.83 ms/i)
```

### Deep Schema Benchmark

The `examples/deep_schema_compilation_and_evaluation_benchmark.rb` tests performance with deep dependency chains:

```
=== Compilation Times ===
compile  50-deep:   22.6 ms
compile 100-deep:   14.5 ms
compile 150-deep:   28.3 ms

=== Evaluation Performance ===
eval  50-deep:  1,998.1 i/s  (500 μs/i)
eval 100-deep:   513.6 i/s  (1.95 ms/i)
eval 150-deep:   240.9 i/s  (4.15 ms/i)
```

**Key Performance Characteristics:**

- **Sub-millisecond evaluation** for moderate complexity (50-deep: ~500μs, 1k-wide: ~950μs per evaluation)
- **Linear compilation scaling** with schema width and depth (O(n) where n = number of declarations)
- **Stack-safe deep dependency chains** up to 150+ levels without Ruby stack overflow  
- **Efficient dependency resolution** through topological sorting and memoization
- **Memory-optimized execution** with compiled lambda functions and cached intermediate results

**Architecture Benefits:**

- **Compile-once, evaluate-many**: Schema compilation happens once, evaluations are pure computation
- **Dependency graph optimization**: Only computes values that are actually needed for the requested output
- **Type-safe execution**: No runtime type checking overhead after compilation
- **Memoized intermediate values**: Avoids redundant calculations within evaluation cycles
- **Depth vs Width trade-offs**: Deep chains slower than wide schemas due to sequential dependencies

Run the benchmarks yourself:
```bash
bundle exec ruby examples/wide_schema_compilation_and_evaluation_benchmark.rb
bundle exec ruby examples/deep_schema_compilation_and_evaluation_benchmark.rb
```



