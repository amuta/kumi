# Kumi 

[![CI](https://github.com/amuta/kumi/workflows/CI/badge.svg)](https://github.com/amuta/kumi/actions)
[![Gem Version](https://badge.fury.io/rb/kumi.svg)](https://badge.fury.io/rb/kumi)

Kumi is a computational rules engine for Ruby (plus static validation, dependency tracking, and more)

It is well-suited for scenarios with complex, interdependent calculations, enforcing validation and consistency across your business rules while maintaining performance.



## What can you build?

Calculate U.S. federal taxes in 30 lines of validated, readable code:

```ruby
module FederalTax2024
  extend Kumi::Schema
  
  schema do
    input do
      float  :income
      string :filing_status, domain: %w[single married_joint]
    end
    
    # Standard deduction by filing status
    trait :single,  input.filing_status == "single"
    trait :married, input.filing_status == "married_joint"
    
    value :std_deduction do
      on single,  14_600
      on married, 29_200
      base        21_900  # head_of_household
    end
    
    value :taxable_income, fn(:max, [input.income - std_deduction, 0])
    
    # Federal tax brackets
    value :fed_breaks do
      on single,  [11_600, 47_150, 100_525, 191_950, 243_725, 609_350, Float::INFINITY]
      on married, [23_200, 94_300, 201_050, 383_900, 487_450, 731_200, Float::INFINITY]
    end
    
    value :fed_rates, [0.10, 0.12, 0.22, 0.24, 0.32, 0.35, 0.37]
    value :fed_calc,  fn(:piecewise_sum, taxable_income, fed_breaks, fed_rates)
    value :fed_tax,   fed_calc[0]
    
    # FICA taxes
    value :ss_tax, fn(:min, [input.income, 168_600]) * 0.062
    value :medicare_tax, input.income * 0.0145
    
    value :total_tax, fed_tax + ss_tax + medicare_tax
    value :after_tax, input.income - total_tax
  end
end

# Use it
result = FederalTax2024.from(income: 100_000, filing_status: "single")
result[:total_tax]   # => 21,491.00
result[:after_tax]   # => 78,509.00
```

Real tax calculation with brackets, deductions, and FICA caps. Validation happens during schema definition.

Is is well-suited for scenarios with complex, interdependent calculations, enforcing ...

## Installation

```bash
# Requires Ruby 3.0+
# No external dependencies
gem install kumi
```

## Core Features

## Key Concepts

Kumi schemas are built from four simple primitives that compose into powerful business logic:

**Inputs** define the data flowing into your schema with built-in validation:
```ruby
input do
  float :price, domain: 0..1000.0      # Validates range
  string :category, domain: %w[standard premium]  # Validates inclusion
end
```

**Values** are computed attributes that automatically memoize their results
```ruby
value :subtotal, input.price * input.quantity
value :tax_rate, 0.08
value :tax_amount, subtotal * tax_rate
```

**Traits** are boolean conditions that enable branching logic:
```ruby
trait :bulk_order, input.quantity >= 100
trait :premium_customer, input.tier == "premium"

value :discount do
  on bulk_order & premium_customer, 0.25  # 25% for bulk premium orders
  on bulk_order, 0.15                     # 15% for bulk orders
  on premium_customer, 0.10               # 10% for premium customers
  base 0.0                                # No discount otherwise
end
```

**Functions** provide computational building blocks:

```ruby
value :final_price, [subtotal - discount_amount, 0].max
value :monthly_payment, fn(:pmt, rate: 0.05/12, nper: 36, pv: -loan_amount)
```
Note: You can find a list all core functions [FUNCTIONS.md](docs/FUNCTIONS.md)


These primitives are statically analyzed during schema definition, catching logical errors before runtime and ensuring your business rules are internally consistent.


### Static Analysis

Kumi catches real business logic errors during schema definition:

```ruby
module CommissionCalculator
  extend Kumi::Schema
  
  schema do
    input do
      float :sales_amount, domain: 0..Float::INFINITY
      integer :years_experience, domain: 0..50
      string :region, domain: %w[east west north south]
    end
    
    # Commission tiers based on experience
    trait :junior, input.years_experience < 2
    trait :senior, input.years_experience >= 5
    trait :veteran, input.years_experience >= 10
    
    # Base commission rates
    value :base_rate do
      on veteran, 0.08
      on senior, 0.06
      on junior, 0.04
      base 0.05
    end
    
    # Regional multipliers
    value :regional_bonus do
      on input.region == "west", 1.2  # West coast bonus
      on input.region == "east", 1.1  # East coast bonus
      base 1.0
    end
    
    # Problem: Veteran bonus conflicts with senior cap
    value :experience_bonus do
      on veteran, 2.0      # Veterans get 2x bonus
      on senior, 1.5       # Seniors get 1.5x bonus  
      base 1.0
    end
    
    value :total_rate, base_rate * regional_bonus * experience_bonus
    
    # Business rule error: Veterans (10+ years) are also seniors (5+ years)
    # This creates impossible logic in commission caps
    trait :capped_senior, :senior & (total_rate <= 0.10)  # Senior cap
    trait :uncapped_veteran, :veteran & (total_rate > 0.10)  # Veteran override
    
    value :final_commission do
      on capped_senior & uncapped_veteran, "Impossible!"  # Can't be both
      on uncapped_veteran, input.sales_amount * total_rate
      on capped_senior, input.sales_amount * 0.10
      base input.sales_amount * total_rate
    end
  end
end

# => conjunction `capped_senior AND uncapped_veteran` is impossible
```

Kumi also enables safe recursive patterns when conditions are mutually exclusive:

```ruby
module MathematicalPredicates
  extend Kumi::Schema
  
  schema do
    input do
      integer :n
    end

    trait :n_is_zero, input.n, :==, 0
    trait :n_is_one, input.n, :==, 1

    value :is_even do
      on n_is_zero, true
      on n_is_one, false
      base fn(:not, is_odd)  # Safe mutual recursion
    end

    value :is_odd do
      on n_is_zero, false  
      on n_is_one, true
      base fn(:not, is_even)  # Safe mutual recursion
    end
  end
end

# Compiles successfully - conditions are mutually exclusive
runner = MathematicalPredicates.from(n: 0)
runner[:is_even]  # => true
runner[:is_odd]   # => false
```

### Automatic Memoization

Each value is computed exactly once:

```ruby
runner = FederalTax2024.from(income: 250_000, filing_status: "married_joint")

# First access computes full dependency chain
runner[:total_tax]     # => 52,937.50

# Subsequent access uses cached values
runner[:fed_tax]       # => 37,437.50 (cached)
runner[:after_tax]     # => 197,062.50 (cached)
```

### Introspection

See exactly how any value was calculated:

```ruby
Kumi::Explain.call(FederalTax2024, :fed_tax, inputs: {income: 100_000, filing_status: "single"})
# => fed_tax = fed_calc[0]
#    = (fed_calc = piecewise_sum(taxable_income, fed_breaks, fed_rates)
#       = piecewise_sum(85,400, [11,600, 47,150, ...], [0.10, 0.12, ...])
#       = [15,099.50, 0.22])
#    = 15,099.50
```

## Suggested Use Cases

- Complex interdependent business rules
- Tax calculation engines (as demonstrated)
- Insurance premium calculators
- Loan amortization schedules
- Commission structures with complex tiers
- Pricing engines with multiple discount rules

**Not suitable for:**
- Simple conditional statements
- Sequential procedural workflows  
- Rules that change during execution
- High-frequency real-time processing

## Performance

Benchmarks on Linux with Ruby 3.3.8 on a Dell Latitude 7450:
- 50-deep dependency chain: **740,000/sec** (analysis <50ms)
- 1,000 attributes:         **131,000/sec** (analysis <50ms)
- 10,000 attributes:        **14,200/sec**  (analysis ~300ms)

## Learn More

- [DSL Syntax Reference](docs/SYNTAX.md)
- [Examples](examples/)/

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/amuta/kumi.

## License

MIT License. See [LICENSE](LICENSE).