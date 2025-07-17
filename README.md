# Kumi

A declarative decision-modeling compiler for Ruby that transforms complex business rules into executable dependency graphs with comprehensive static type checking.

## Overview

Kumi provides a powerful DSL for modeling complex business logic through:
- **Multi-pass analysis** that validates rule interdependencies and detects cycles
- **Static type system** with declared and inferred types
- **Dependency-driven evaluation** for optimal performance
- **Input block system** for explicit field declarations and type safety
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

```ruby
require 'kumi'

# Define a schema with explicit input declarations and business rules
schema = Kumi.schema do
  input do
    key :score, type: Integer
    key :base_discount, type: Float
    key :customer_tier, type: String
  end
  
  predicate :high_risk, fn(:>, input.score, 80)
  predicate :premium_customer, fn(:==, input.customer_tier, "premium")
  
  value :discount_multiplier, fn(:conditional, 
    ref(:premium_customer), 1.5,
    fn(:conditional, ref(:high_risk), 0.8, 1.2)
  )
  
  value :final_discount, fn(:multiply, input.base_discount, ref(:discount_multiplier))
end

# Execute with input data
runner = schema.runner
puts runner.fetch(:final_discount, {
  score: 75, 
  base_discount: 10.0, 
  customer_tier: "premium"
}) # => 15.0
```INT

## Core Features

### Input Block System
All schemas must declare expected input fields with optional type annotations:

```ruby
schema do
  input do
    key :age, type: Integer
    key :name, type: String
    key :scores, type: Array
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
- Primitives: `Integer`, `Float`, `String`, `Bool`, `Numeric`, `Any`
- Collections: `array(T)`, `set(T)`, `hash(K, V)`
- Unions: `A | B` for multiple possible types
- Optionals: `optional(T)` for nullable values

## DSL Syntax

### Basic Declarations
- `predicate :name, expression` - Boolean conditions
- `value :name, expression` - Computed values
- `value :name do ... end` - Conditional logic with `on condition, result` and `base default`

### Expressions
- `input.field_name` - Access input data (replaces deprecated `key(:field)`)
- `ref(:name)` - Reference other declarations
- `fn(:function, args...)` - Function calls
- `[element1, element2]` - Lists
- Literals: numbers, Strings, booleans

### Available Functions
Core functions include arithmetic (`add`, `subtract`, `multiply`, `divide`), comparison (`==`, `>`, `<`, `>=`, `<=`), logical (`and`, `or`, `not`), String operations (`concat`, `upcase`, `downcase`), and collection operations (`sum`, `first`, `last`, `size`).

## Examples

### Simple Decision Logic
```ruby
schema do
  input do
    key :temperature, type: Float
    key :humidity, type: Float
  end
  
  predicate :hot, fn(:>, input.temperature, 80.0)
  predicate :humid, fn(:>, input.humidity, 60.0)
  
  value :comfort_level do
    on fn(:and, ref(:hot), ref(:humid)), "uncomfortable"
    on ref(:hot), "warm"
    on ref(:humid), "muggy"
    base "pleasant"
  end
end
```

### Complex Business Rules
```ruby
schema do
  input do
    key :credit_score, type: Integer
    key :annual_income, type: Float
    key :loan_amount, type: Float
    key :employment_years, type: Integer
  end
  
  predicate :good_credit, fn(:>=, input.credit_score, 700)
  predicate :stable_income, fn(:>=, input.employment_years, 2)
  
  value :debt_to_income_ratio, fn(:divide, input.loan_amount, input.annual_income)
  value :risk_score, fn(:multiply, 
    fn(:conditional, ref(:good_credit), 0.3, 0.7),
    fn(:conditional, ref(:stable_income), 0.8, 1.2)
  )
  
  value :approval_status do
    on fn(:and, ref(:good_credit), ref(:stable_income)), "approved"
    on fn(:<, ref(:debt_to_income_ratio), 0.3), "conditional"
    base "denied"
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

*Note: Some examples may be outdated and not compatible with the current input block system. Please refer to the input block typing showcase for current best practices.*

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass: `bundle exec rspec`
5. Ensure code style compliance: `bundle exec rubocop`
6. Submit a pull request

## License

MIT License - see LICENSE file for details.
