# Kumi 

[![CI](https://github.com/amuta/kumi/workflows/CI/badge.svg)](https://github.com/amuta/kumi/actions)
[![Gem Version](https://badge.fury.io/rb/kumi.svg)](https://badge.fury.io/rb/kumi)

Kumi is a computational rules engine for Ruby (plus static validation, dependency tracking, and more)

It is well-suited for scenarios with complex, interdependent calculations, enforcing validation and consistency across your business rules while maintaining performance.



## What can you build?

Calculate U.S. federal taxes:

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

Kumi is well-suited for scenarios with complex, interdependent calculations, enforcing validation and consistency across your business rules while maintaining performance.

## Installation

```bash
# Requires Ruby 3.0+
# No external dependencies
gem install kumi
```

## Core Features

<details>
<summary><strong>📊 Schema Primitives</strong> - Four building blocks for business logic</summary>

### Schema Primitives

Kumi schemas are built from four primitives:

**Inputs** define the data flowing into your schema with built-in validation:
```ruby
input do
  float :price, domain: 0..1000.0      # Validates range
  integer :quantity, domain: 1..10000   # Validates range
  string :tier, domain: %w[standard premium]  # Validates inclusion
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
  on bulk_order, premium_customer, 0.25  # 25% for bulk premium orders
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
Note: You can find a list all core functions in [docs/FUNCTIONS.md](docs/FUNCTIONS.md)

These primitives are statically analyzed during schema definition to catch logical errors before runtime.

</details>

<details>
<summary><strong>🔍 Static Analysis</strong> - Catch business logic errors at definition time</summary>

### Static Analysis

Kumi catches business logic errors that cause runtime failures or silent bugs:

```ruby
module InsurancePolicyPricer
  extend Kumi::Schema
  
  schema do
    input do
      integer :age, domain: 18..80
      string :risk_category, domain: %w[low medium high]
      float :coverage_amount, domain: 50_000..2_000_000
      integer :years_experience, domain: 0..50
      boolean :has_claims
    end
    
    # Risk assessment with subtle interdependencies
    trait :young_driver, input.age < 25
    trait :experienced, input.years_experience >= 5
    trait :high_risk, input.risk_category == "high"
    trait :senior_driver, input.age >= 65
    
    # Base premium calculation
    value :base_premium, input.coverage_amount * 0.02
    
    # Experience adjustment with subtle circular reference
    value :experience_factor do
      on experienced & young_driver, experience_discount * 0.8  # ❌ Uses experience_discount before it's defined
      on experienced, 0.85
      on young_driver, 1.25
      base 1.0
    end
    
    # Risk multipliers that create impossible combinations
    value :risk_multiplier do
      on high_risk & experienced, 1.5    # High risk but experienced
      on high_risk, 2.0                  # Just high risk
      on low_risk & young_driver, 0.9    # ❌ low_risk is undefined (typo for input.risk_category)
      base 1.0
    end
    
    # Claims history impact
    trait :claims_free, fn(:not, input.has_claims)
    trait :perfect_record, claims_free & experienced & fn(:not, young_driver)
    
    # Discount calculation with type error
    value :experience_discount do
      on perfect_record, input.years_experience + "%" # ❌ String concatenation with integer
      on claims_free, 0.95
      base 1.0
    end
    
    # Premium calculation chain
    value :adjusted_premium, base_premium * experience_factor * risk_multiplier
    
    # Age-based impossible logic
    trait :mature_professional, senior_driver & experienced & young_driver  # ❌ Can't be senior AND young
    
    # Final premium with self-referencing cascade
    value :final_premium do
      on mature_professional, adjusted_premium * 0.8
      on senior_driver, adjusted_premium * senior_adjustment  # ❌ senior_adjustment undefined
      base final_premium * 1.1  # ❌ Self-reference in base case
    end
    
    # Monthly payment calculation with function arity error
    value :monthly_payment, fn(:divide, final_premium)  # ❌ divide needs 2 arguments, got 1
  end
end

# Static analysis catches these errors:
# ❌ Circular reference: experience_factor → experience_discount → experience_factor
# ❌ Undefined reference: low_risk (should be input.risk_category == "low")
# ❌ Type mismatch: integer + string in experience_discount
# ❌ Impossible conjunction: senior_driver & young_driver
# ❌ Undefined reference: senior_adjustment
# ❌ Self-reference cycle: final_premium references itself in base case
# ❌ Function arity error: divide expects 2 arguments, got 1
```

**Bounded Recursion**: Kumi allows mutual recursion when cascade conditions are mutually exclusive:

```ruby
trait :is_forward, input.operation == "forward"
trait :is_reverse, input.operation == "reverse"

# Safe mutual recursion - conditions are mutually exclusive
value :forward_processor do
  on is_forward, input.value * 2        # Direct calculation
  on is_reverse, reverse_processor + 10  # Delegates to reverse (safe)
  base "invalid operation"
end

value :reverse_processor do
  on is_forward, forward_processor - 5   # Delegates to forward (safe) 
  on is_reverse, input.value / 2         # Direct calculation
  base "invalid operation"
end

# Usage examples:
# operation="forward", value=10  => forward: 20, reverse: 15
# operation="reverse", value=10  => forward: 15, reverse: 5  
# operation="unknown", value=10  => both: "invalid operation"
```

This compiles because `operation` can only be "forward" or "reverse", never both. Each recursion executes one step before hitting a direct calculation.

</details>

<details>
<summary><strong>🔍 Array Broadcasting</strong> - Automatic vectorization over array fields</summary>

### Array Broadcasting

Kumi broadcasts operations over array fields for element-wise computation:

```ruby
schema do
  input do
    array :line_items do
      float   :price
      integer :quantity
      string  :category
    end
    float :tax_rate
  end

  # Element-wise computation - broadcasts over each item
  value :subtotals, input.line_items.price * input.line_items.quantity
  
  # Element-wise traits - applied to each item
  trait :is_taxable, (input.line_items.category != "digital")
  
  # Aggregation operations - consume arrays to produce scalars
  value :total_subtotal, fn(:sum, subtotals)
  value :item_count, fn(:size, input.line_items)
end
```

**Dimension Mismatch Detection**: Operations across different arrays generate error messages:

```ruby
schema do
  input do
    array :items do
      string :name
    end
    array :logs do  
      string :user_name
    end
  end

  # This generates an error
  trait :same_name, input.items.name == input.logs.user_name
end

# Error:
# Cannot broadcast operation across arrays from different sources: items, logs. 
# Problem: Multiple operands are arrays from different sources:
#   - Operand 1 resolves to array(string) from array 'items'
#   - Operand 2 resolves to array(string) from array 'logs'
# Direct operations on arrays from different sources is ambiguous and not supported.
```

</details>

<details>
<summary><strong>💾 Automatic Memoization</strong> - Each value computed exactly once</summary>

### Automatic Memoization

Each value is computed exactly once:

```ruby
runner = FederalTax2024.from(income: 250_000, filing_status: "married_joint")

# First access computes full dependency chain
runner[:total_tax]     # => 53,155.20

# Subsequent access uses cached values
runner[:fed_tax]       # => 39,077.00 (cached)
runner[:after_tax]     # => 196,844.80 (cached)
```

</details>

<details>
<summary><strong>🔍 Introspection</strong> - See exactly how values are calculated</summary>

### Introspection

Show how values are calculated:

```ruby
Kumi::Explain.call(FederalTax2024, :fed_tax, inputs: {income: 100_000, filing_status: "single"})
# => fed_tax = fed_calc[0]
#    = (fed_calc = piecewise_sum(taxable_income, fed_breaks, fed_rates)
#       = piecewise_sum(85,400, [11,600, 47,150, ...], [0.10, 0.12, ...])
#       = [15,099.50, 0.22])
#    = 15,099.50
```

</details>

## Usage

**Suitable for:**
- Complex interdependent business rules
- Tax calculation engines
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