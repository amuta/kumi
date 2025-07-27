# Kumi 

[![CI](https://github.com/amuta/kumi/workflows/CI/badge.svg)](https://github.com/amuta/kumi/actions)
[![Gem Version](https://badge.fury.io/rb/kumi.svg)](https://badge.fury.io/rb/kumi)

Kumi is a computational rules engine for Ruby (plus static validation, dependency tracking, and more)

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
gem install kumi
```

## Core Features

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

## Use Cases

**Suitable for:**
- Complex interdependent business rules
- Mathematical calculations with multiple steps
- Conditional logic with overlapping categories
- Rules requiring static validation and audit trails

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

- [DSL Syntax Reference](documents/SYNTAX.md)
- [Examples](examples/)/

## License

MIT License. See [LICENSE](LICENSE).