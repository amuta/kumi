# Unsatisfiability Detection

Analyzes logical relationships across dependency chains to detect impossible rule combinations at compile time.

## Example: Credit Card Approval System

This schema contains impossible rule combinations:

```ruby
module CreditCardApproval
  extend Kumi::Schema
  
  schema do
    input do
      integer :annual_income
      integer :monthly_debt
      integer :credit_score, domain: 300..850
      string  :employment_type, domain: %w[full_time part_time contract self_employed]
    end

    # Financial calculations
    value :monthly_income, input.annual_income / 12
    value :available_monthly, monthly_income - input.monthly_debt
    value :credit_limit_base, input.annual_income * 0.3
    value :score_multiplier, (input.credit_score - 600) * 0.01
    value :final_credit_limit, credit_limit_base * score_multiplier
    value :employment_stability_factor, 
          input.employment_type == "full_time" ? 1.0 :
          input.employment_type == "part_time" ? 0.7 :
          input.employment_type == "contract" ? 0.5 : 0.3
    
    # Business rules
    trait :stable_income, (input.annual_income >= 60_000)
    trait :good_credit, (input.credit_score >= 700)
    trait :high_available_income, (available_monthly >= 4_000)
    trait :premium_limit_qualified, (final_credit_limit >= 50_000)
    trait :stable_employment, (input.employment_type == "full_time")
    trait :high_stability_factor, (employment_stability_factor >= 0.8)
    trait :excellent_credit, (input.credit_score == 900)

    # Approval tiers - which combinations are impossible?
    value :approval_tier do
      on stable_income,good_credit,premium_limit_qualified, "platinum_tier"
      on stable_employment,high_stability_factor, "executive_tier"  
      on excellent_credit,good_credit, "perfect_score_tier"
      on stable_income,good_credit, "standard_tier"
      base "manual_review"
    end
  end
end
```

**Detected errors:**

```
SemanticError: 
conjunction `excellent_credit AND good_credit` is impossible
conjunction `excellent_credit` is impossible
```

**Root cause:**
- `excellent_credit` requires `credit_score == 900`
- Input domain constrains `credit_score` to `300..850`
- Any cascade condition using `excellent_credit` becomes impossible

## Detection Mechanisms

- Domain constraint violations: `field == value` where value is outside declared domain
- Cascade condition analysis: each `on` condition checked independently  
- OR expression handling: impossible only if both sides are impossible
- Cross-variable mathematical constraint analysis