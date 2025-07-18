# Kumi

A declarative decision-modeling compiler for Ruby that transforms complex business rules into executable dependency graphs with comprehensive static type checking.

## Overview

Kumi provides a powerful DSL for modeling complex business logic through:
- **Multi-pass analysis** that validates rule interdependencies and detects cycles
- **Static type system** with declared and inferred types
- **Dependency-driven evaluation** for optimal performance
- **Input block system** for explicit field declarations and type safety
- **Object-oriented design** with extensible schema classes
- **Comprehensive error reporting** with precise location tracking

## Installation

```bash
gem install kumi
```

Or add to your Gemfile:

```ruby
gem 'kumi'
```

## Quick Start

Kumi supports both functional and object-oriented approaches. **The object-oriented approach is recommended** for production applications as it provides better encapsulation, reusability, and testability.

### Functional Approach
```ruby
require 'kumi'

# Direct schema definition
schema = Kumi.schema do
  input do
    key :score, type: :integer
    key :base_discount, type: :float
    key :customer_tier, type: :string
  end
  
  predicate :high_risk, fn(:>, input.score, 80)
  predicate :premium_customer, fn(:==, input.customer_tier, "premium")
  
  value :discount_multiplier, fn(:conditional, 
    ref(:premium_customer), 1.5,
    fn(:conditional, ref(:high_risk), 0.8, 1.2)
  )
  
  value :final_discount, fn(:multiply, input.base_discount, ref(:discount_multiplier))
end

runner = schema.runner
puts runner.fetch(:final_discount, {
  score: 75, 
  base_discount: 10.0, 
  customer_tier: "premium"
}) # => 15.0
```

### Object-Oriented Approach (Recommended)
```ruby
require 'kumi'

class DiscountCalculator
  extend Kumi::Schema
  
  schema do
    input do
      key :score, type: :integer
      key :base_discount, type: :float
      key :customer_tier, type: :string
    end
    
    predicate :high_risk, fn(:>, input.score, 80)
    predicate :premium_customer, fn(:==, input.customer_tier, "premium")
    
    value :discount_multiplier, fn(:conditional, 
      ref(:premium_customer), 1.5,
      fn(:conditional, ref(:high_risk), 0.8, 1.2)
    )
    
    value :final_discount, fn(:multiply, input.base_discount, ref(:discount_multiplier))
  end
  
  def self.calculate_discount(customer_data)
    from(customer_data).fetch(:final_discount)
  end
  
  def self.get_customer_tier(customer_data)
    from(customer_data).fetch(:premium_customer) ? "Premium" : "Standard"
  end
end

# Clean, domain-focused usage
discount = DiscountCalculator.calculate_discount({
  score: 75, 
  base_discount: 10.0, 
  customer_tier: "premium"
}) # => 15.0

tier = DiscountCalculator.get_customer_tier(customer_data)
```

## Core Features

### Input Block System
All schemas must declare expected input fields with optional type annotations:

```ruby
schema do
  input do
    key :age, type: :integer
    key :name, type: :string
    key :scores, type: array(:any)
    key :dynamic
  end
  
  # Use input.field_name to access fields
  predicate :adult, fn(:>=, input.age, 18)
  value :greeting, fn(:concat, "Hello, ", input.name)
end
```

note: when the type is not declared, it will be considered as `Any` type
(Later I will add a flag for strict_type: true)

### Type System
- **Declared Types**: Explicit type declarations in input blocks
- **Inferred Types**: Automatic type inference from expressions
- **Type Checking**: Validates compatibility between declared and inferred types
- **Rich Error Messages**: Shows type provenance and location information

### Available Types
- Primitives: `:integer`, `:float`, `:string`, `:boolean`, `:any`, `:symbol`, `:regexp`, `:time`, `:date`, `:datetime`
- Collections: `array(:element_type)`, `hash(:key_type, :value_type)`

## DSL Syntax

### Basic Declarations
- `predicate :name, expression` - Boolean conditions
- `value :name, expression` - Computed values
- `value :name do ... end` - Conditional logic with `on predicate1, predicate2, result` and `base default`

### Expressions
- `input.field_name` - Access input data (replaces deprecated `key(:field)`)
- `ref(:name)` - Reference other declarations
- `fn(:function, args...)` - Function calls
- `[element1, element2]` - Lists
- Literals: numbers, Strings, booleans

### Available Functions
Core functions include arithmetic (`add`, `subtract`, `multiply`, `divide`), comparison (`==`, `>`, `<`, `>=`, `<=`), logical (`and`, `or`, `not`), String operations (`concat`, `upcase`, `downcase`), and collection operations (`sum`, `first`, `last`, `size`).

## Examples

### Simple Weather Assessment
```ruby
class WeatherComfort
  extend Kumi::Schema
  
  schema do
    input do
      key :temperature, type: :float
      key :humidity, type: :float
    end
    
    predicate :hot, fn(:>, input.temperature, 80.0)
    predicate :humid, fn(:>, input.humidity, 60.0)
    
    value :comfort_level do
      on :hot, :humid, "uncomfortable"
      on :hot, "warm"
      on :humid, "muggy"
      base "pleasant"
    end
    
    value :recommendation, fn(:conditional,
      fn(:==, ref(:comfort_level), "uncomfortable"), "Stay indoors with AC",
      fn(:conditional,
        fn(:==, ref(:comfort_level), "pleasant"), "Perfect for outdoor activities",
        "Consider light activities"
      )
    )
  end
  
  def self.assess(conditions)
    runner = from(conditions)
    {
      comfort: runner.fetch(:comfort_level),
      recommendation: runner.fetch(:recommendation)
    }
  end
end

# Usage
assessment = WeatherComfort.assess({
  temperature: 75.0,
  humidity: 45.0
})
# => { comfort: "pleasant", recommendation: "Perfect for outdoor activities" }
```

### Loan Approval System
```ruby
class LoanApprovalEngine
  extend Kumi::Schema
  
  schema do
    input do
      key :credit_score, type: :integer, domain: 300..850
      key :annual_income, type: :float
      key :loan_amount, type: :float
      key :employment_years, type: :integer
      key :has_collateral, type: :boolean
    end
    
    predicate :good_credit, fn(:>=, input.credit_score, 700)
    predicate :stable_income, fn(:>=, input.employment_years, 2)
    predicate :low_debt_ratio, fn(:<, fn(:divide, input.loan_amount, input.annual_income), 0.3)
    
    value :debt_to_income_ratio, fn(:divide, input.loan_amount, input.annual_income)
    value :risk_score, fn(:multiply, 
      fn(:conditional, ref(:good_credit), 0.3, 0.7),
      fn(:conditional, ref(:stable_income), 0.8, 1.2)
    )
    
    value :approval_status do
      on :good_credit, :stable_income, "approved"
      on :low_debt_ratio, "conditional"
      base "denied"
    end
    
    value :interest_rate, fn(:conditional,
      fn(:==, ref(:approval_status), "approved"), 3.5,
      fn(:conditional,
        fn(:==, ref(:approval_status), "conditional"), 4.2,
        0.0
      )
    )
  end
  
  def self.evaluate(application)
    runner = from(application)
    {
      status: runner.fetch(:approval_status),
      interest_rate: runner.fetch(:interest_rate),
      debt_ratio: runner.fetch(:debt_to_income_ratio).round(3),
      risk_score: runner.fetch(:risk_score).round(3)
    }
  end
  
  def self.approved?(application)
    from(application).fetch(:approval_status) != "denied"
  end
end

# Usage
result = LoanApprovalEngine.evaluate({
  credit_score: 720,
  annual_income: 75_000.0,
  loan_amount: 200_000.0,
  employment_years: 5,
  has_collateral: true
})
# => { status: "approved", interest_rate: 3.5, debt_ratio: 2.667, risk_score: 0.24 }
```

### Product Pricing Engine
```ruby
class ProductPricing
  extend Kumi::Schema
  
  schema do
    input do
      key :base_price, type: :float
      key :customer_tier, type: :string
      key :quantity, type: :integer
      key :seasonal_demand, type: :string
      key :is_member, type: :boolean
    end
    
    predicate :bulk_order, fn(:>=, input.quantity, 10)
    predicate :premium_customer, fn(:==, input.customer_tier, "premium")
    predicate :high_demand, fn(:==, input.seasonal_demand, "high")
    
    value :tier_discount, fn(:conditional,
      ref(:premium_customer), 0.15,
      fn(:conditional, input.is_member, 0.05, 0.0)
    )
    
    value :quantity_discount, fn(:conditional,
      fn(:>=, input.quantity, 50), 0.20,
      fn(:conditional, ref(:bulk_order), 0.10, 0.0)
    )
    
    value :seasonal_multiplier, fn(:conditional,
      ref(:high_demand), 1.15,
      fn(:conditional, fn(:==, input.seasonal_demand, "low"), 0.9, 1.0)
    )
    
    value :total_discount, fn(:add, ref(:tier_discount), ref(:quantity_discount))
    value :discounted_price, fn(:multiply, input.base_price, fn(:subtract, 1.0, ref(:total_discount)))
    value :final_price, fn(:multiply, ref(:discounted_price), ref(:seasonal_multiplier))
  end
  
  def self.calculate(product_data)
    runner = from(product_data)
    {
      base_price: product_data[:base_price],
      tier_discount: (runner.fetch(:tier_discount) * 100).round(1),
      quantity_discount: (runner.fetch(:quantity_discount) * 100).round(1),
      seasonal_adjustment: ((runner.fetch(:seasonal_multiplier) - 1) * 100).round(1),
      final_price: runner.fetch(:final_price).round(2)
    }
  end
end

# Usage
pricing = ProductPricing.calculate({
  base_price: 100.0,
  customer_tier: "premium",
  quantity: 25,
  seasonal_demand: "normal",
  is_member: true
})
# => { base_price: 100.0, tier_discount: 15.0, quantity_discount: 10.0, 
#      seasonal_adjustment: 0.0, final_price: 75.0 }
```

## Object-Oriented Benefits

### Why Extend Classes with Kumi::Schema?

The object-oriented approach provides several key advantages:

1. **Domain Encapsulation**: Each schema class represents a specific business domain
2. **Reusability**: Schemas become reusable components across your application
3. **Clean APIs**: Custom methods provide domain-specific interfaces
4. **Testability**: Easy to unit test individual business logic components
5. **Maintainability**: Business rules are organized by domain, not scattered

### Implementation Patterns

#### Simple Extension
```ruby
class RiskAssessment
  extend Kumi::Schema
  
  schema do
    # Your business logic here
  end
  
  def self.assess_risk(data)
    from(data).fetch(:risk_level)
  end
end
```

#### Multiple Outputs
```ruby
class EmployeeEvaluation
  extend Kumi::Schema
  
  schema do
    input do
      key :performance_score, type: :integer
      key :years_of_service, type: :integer
      key :department, type: :string
    end
    
    predicate :high_performer, fn(:>=, input.performance_score, 85)
    predicate :senior_employee, fn(:>=, input.years_of_service, 5)
    
    value :promotion_eligible, fn(:and, ref(:high_performer), ref(:senior_employee))
    value :bonus_multiplier, fn(:conditional, ref(:high_performer), 1.5, 1.0)
    value :development_track, fn(:conditional, 
      ref(:senior_employee), "leadership", "individual_contributor"
    )
  end
  
  def self.evaluate(employee_data)
    runner = from(employee_data)
    {
      promotion_eligible: runner.fetch(:promotion_eligible),
      bonus_multiplier: runner.fetch(:bonus_multiplier),
      development_track: runner.fetch(:development_track)
    }
  end
  
  def self.promotion_eligible?(employee_data)
    from(employee_data).fetch(:promotion_eligible)
  end
  
  def self.recommended_bonus(employee_data, base_bonus)
    multiplier = from(employee_data).fetch(:bonus_multiplier)
    base_bonus * multiplier
  end
end
```

#### Inheritance for Related Domains
```ruby
class BaseInsuranceCalculator
  extend Kumi::Schema
  
  schema do
    input do
      key :age, type: :integer
      key :coverage_amount, type: :float
      key :risk_factors, type: array(:string)
    end
    
    predicate :high_risk_age, fn(:or, fn(:<, input.age, 25), fn(:>, input.age, 65))
    value :base_premium, fn(:multiply, input.coverage_amount, 0.02)
  end
end

class AutoInsurance < BaseInsuranceCalculator
  schema do
    input do
      key :driving_record, type: :string
      key :vehicle_year, type: :integer
    end
    
    predicate :good_driver, fn(:==, input.driving_record, "clean")
    predicate :new_vehicle, fn(:>, input.vehicle_year, 2020)
    
    value :risk_multiplier, fn(:conditional,
      fn(:and, ref(:good_driver), ref(:new_vehicle)), 0.8,
      fn(:conditional, ref(:good_driver), 0.9, 1.2)
    )
    
    value :final_premium, fn(:multiply, ref(:base_premium), ref(:risk_multiplier))
  end
  
  def self.quote(driver_data)
    from(driver_data).fetch(:final_premium).round(2)
  end
end
```

## Architecture

Kumi uses a multi-pass analysis system:

1. **Name Indexing** - Find all declarations and check for duplicates
2. **Input Collection** - Gather field metadata and validate consistency
3. **Definition Validation** - Validate basic structure
4. **Dependency Resolution** - Build dependency graph
5. **Cycle Detection** - Find circular dependencies
6. **Topological Sorting** - Create evaluation order
7. **Type Inference** - Infer types for all declarations
8. **Type Checking** - Validate function types and compatibility

## Error Handling

Kumi provides detailed error messages with:
- Precise location information (file, line, column)
- Type provenance (declared vs inferred types)
- Clear descriptions of type mismatches
- Suggestions for fixing common issues

```ruby
# Example error:
# at example.rb:10:5: argument 1 of `fn(:add)` expects int | Float, 
# got input field `name` of declared type String
```

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop

# Run both tests and linter
rake

# Build gem
gem build kumi.gemspec
```

## Examples Directory

The `examples/` directory contains comprehensive examples:
- `input_block_typing_showcase.rb` - Complete demonstration of input block typing features

*Note: Examples demonstrate both functional and object-oriented approaches. The object-oriented pattern (extending classes with `Kumi::Schema`) is recommended for production applications.*

### Getting Started with Object-Oriented Schemas

1. **Start Simple**: Create a class and extend `Kumi::Schema`
2. **Define Schema**: Use the `schema do...end` block to define business logic
3. **Add Methods**: Create class methods that use `from(data)` to access the runner
4. **Test Easily**: Each class becomes a testable unit of business logic

```ruby
# Your first schema class
class MyBusinessLogic
  extend Kumi::Schema
  
  schema do
    input do
      key :my_field, type: :string
    end
    
    value :my_result, fn(:upcase, input.my_field)
  end
  
  def self.process(data)
    from(data).fetch(:my_result)
  end
end

result = MyBusinessLogic.process({ my_field: "hello" })
# => "HELLO"
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass: `bundle exec rspec`
5. Ensure code style compliance: `bundle exec rubocop`
6. Submit a pull request

## License

MIT License - see LICENSE file for details.
