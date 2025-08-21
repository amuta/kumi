# Kumi 

[![CI](https://github.com/amuta/kumi/workflows/CI/badge.svg)](https://github.com/amuta/kumi/actions)
[![Gem Version](https://badge.fury.io/rb/kumi.svg)](https://badge.fury.io/rb/kumi)

**Kumi** is a declarative rules-and-calculation DSL for Ruby. It compiles business logic into a **typed, analyzable dependency graph** with **vector semantics** over nested data, performs **static checks** at definition time, **lowers to a compact IR**, and executes **deterministically**.

It handles complex, interdependent calculations with validation and consistency checking.


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

Real tax calculation with brackets, deductions, and FICA caps. 

Validation happens during schema definition.

## Installation

```bash
# Requires Ruby 3.1+
# No external dependencies
gem install kumi
```

## Core Features

<details>
<summary><strong>Schema Primitives</strong> - Four building blocks for business logic</summary>

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

**Traits** are boolean conditions for branching logic:
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

**Functions** are computational building blocks:

```ruby
value :final_price, [subtotal - discount_amount, 0].max
value :monthly_payment, fn(:pmt, rate: 0.05/12, nper: 36, pv: -loan_amount)
```
Note: You can find a list all core functions in [docs/FUNCTIONS.md](docs/FUNCTIONS.md)

</details>

<details>
<summary><strong>Analysis & Introspection</strong> - Static verification, runtime inspection, and metadata extraction</summary>

### Analysis & Introspection

Kumi provides comprehensive analysis capabilities - catching errors at definition time and exposing schema structure for tooling and debugging.

#### **Static Analysis: Catch Errors Early**

Kumi catches many types of business logic errors that cause runtime failures or silent bugs:

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

#### **Runtime Introspection: Debug and Understand**

**Explainability**: Trace exactly how any value is computed, step-by-step. This is invaluable for debugging complex logic and auditing results.

```ruby
Kumi::Explain.call(FederalTax2024, :fed_tax, inputs: {income: 100_000, filing_status: "single"})
# => fed_tax = fed_calc[0]
#    = (fed_calc = piecewise_sum(taxable_income, fed_breaks, fed_rates)
#       = piecewise_sum(85_400, [11_600, 47_150, ...], [0.10, 0.12, ...])
#       = [15_099.50, 0.22])
#    = 15_099.50
```

#### **Schema Metadata API: Build Tooling**

Programmatically access the analyzed structure of your schema to build tools like form generators, documentation sites, or custom validators.

```ruby
metadata = FederalTax2024.schema_metadata

# Processed, tool-friendly metadata
metadata.inputs           # => { name: { type: :string, domain: ... } }
metadata.values           # => { name: { dependencies: [...], expression: "..." } }
metadata.traits           # => { name: { condition: "...", dependencies: [...] } }

# Raw analyzer state for deep analysis
metadata.dependencies     # Dependency graph between all declarations
metadata.evaluation_order # Topologically sorted computation order

# Export to standard formats
metadata.to_h             # => Serializable hash for JSON/APIs
metadata.to_json_schema   # => JSON Schema for input validation
```

#### **AST Visualization: See the Structure**

For deep debugging, you can print the raw Abstract Syntax Tree (AST) of a schema.

```ruby
puts Kumi::Support::SExpressionPrinter.print(FederalTax2024.__syntax_tree__)
# => (Root
#      inputs: [
#        (InputDeclaration :income :float)
#        (InputDeclaration :filing_status :string domain: ["single", "married_joint"])
#      ]
#      traits: [...]
#      attributes: [...])
```

</details>

<details>
<summary><strong>Hierarchical Broadcasting</strong> - Vectorization over nested data structures</summary>

### Hierarchical Broadcasting

Kumi broadcasts operations over hierarchical data structures with two complementary access modes for maximum flexibility.

See [docs/features/hierarchical-broadcasting.md](docs/features/hierarchical-broadcasting.md) for detailed documentation.

**Business Scenario**: E-commerce checkout with dynamic pricing rules

> **"As an e-commerce platform, I need to calculate order totals with complex discount rules:**
> - Premium members get 15% off electronics
> - Bulk orders (5+ items) get 10% off that item
> - Free shipping on orders over $100
> - Calculate: item subtotals, total discounts, shipping, final total
> 
> **The challenge:** Each order has different items, quantities, categories, and customer tiers. The discount logic involves multiple conditions - some items qualify for multiple discounts, others for none. Traditional pricing code requires nested if-statements and manual calculations."

**Kumi Solution** (16 lines of declarative pricing logic):
```ruby
module OrderPricing
  extend Kumi::Schema
  
  schema do
    input do
      array :items do
        float   :price
        integer :quantity
        string  :category
      end
      string :customer_tier
      float  :shipping_threshold
    end
    
    # Calculate item subtotals and discount eligibility
    value :subtotals, input.items.price * input.items.quantity
    trait :electronics, input.items.category == "electronics"
    trait :bulk_item, input.items.quantity >= 5
    trait :premium_customer, input.customer_tier == "premium"
    
    # Apply layered discounts (premium + bulk can stack)
    trait :premium_electronics, premium_customer & electronics
    trait :stacked_discount, premium_electronics & bulk_item
    
    value :discounted_prices do
      on stacked_discount, input.items.price * 0.75      # 15% + 10% = 25% off
      on premium_electronics, input.items.price * 0.85   # 15% off
      on bulk_item, input.items.price * 0.90             # 10% off
      base input.items.price                              # No discount
    end
    
    value :final_subtotals, discounted_prices * input.items.quantity
    
    # Order totals and conditional shipping
    value :subtotal, fn(:sum, final_subtotals)
    value :total_savings, fn(:sum, subtotals) - subtotal
    value :shipping, subtotal > input.shipping_threshold ? 0.0 : 9.99
    value :total, subtotal + shipping
  end
end
```

**Mixed Access Modes**: Both object and element access can be used together in the same schema:

```ruby
module UserAnalytics
  extend Kumi::Schema
  
  schema do
    input do
      # Object access mode - structured business data
      array :users do
        string :name
        integer :age
      end
      
      # Element access mode - multi-dimensional raw arrays
      array :recent_purchases do
        element :integer, :days_ago
      end
    end

    # Object access works normally
    value :user_names, input.users.name
    value :avg_age, fn(:avg, input.users.age)
    
    # Element access handles nested arrays with progressive path traversal
    value :all_purchase_days, fn(:flatten, input.recent_purchases.days_ago)
    value :recent_flags, input.recent_purchases.days_ago < 5
    trait :has_recent_purchase, fn(:any?, fn(:flatten, recent_flags))
    
    # Progressive dimensional analysis - each path level goes deeper
    value :purchase_dimensions, [
      fn(:size, input.recent_purchases),           # Number of purchase groups
      fn(:size, input.recent_purchases.days_ago)  # Total individual purchase days
    ]
    
    # Mixed usage in conditions
    trait :adult_users, input.users.age >= 18
    value :adult_count, fn(:count_if, adult_users)
  end
end

# Works with mixed data structures
result = UserAnalytics.from({
  users: [{ name: "Alice", age: 25 }, { name: "Bob", age: 17 }],
  recent_purchases: [[1, 3, 7], [2, 4], [10, 15]]  # Nested arrays
})

result[:user_names]          # => ["Alice", "Bob"]
result[:has_recent_purchase] # => true (some purchases < 5 days ago)
result[:adult_count]         # => 1
result[:purchase_dimensions] # => [3, 8] (3 groups, 8 total days)
```

</details>

<details>
<summary><strong>Memoization</strong> - Each value computed exactly once</summary>

### Memoization

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

## Usage

**Suitable for:**
- Complex interdependent business rules
- Tax calculation engines
- Insurance premium calculators
- Commission structures with complex tiers
- Pricing engines with multiple discount rules

**Not suitable for:**
- Basic conditional statements
- Sequential procedural workflows  
- High-frequency processing

## Performance

Benchmarks on Linux with Ruby 3.3.8 on a Dell Latitude 7450:
- 50-deep dependency chain: **740,000/sec** (analysis <50ms)
- 1,000 attributes:         **131,000/sec** (analysis <50ms)
- 10,000 attributes:        **14,200/sec**  (analysis ~300ms)

See [docs/features/performance.md](docs/features/performance.md) for detailed benchmarks.

## What Kumi does not guarantee 

Lambdas (e.g. -> inside the schema), external IO, floating-point vs bignum, time-zone math differences, etc.

## Learn More

- [DSL Syntax Reference](docs/SYNTAX.md)
- [Examples](examples/)/

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/amuta/kumi.

## License

MIT License. See [LICENSE](LICENSE).
