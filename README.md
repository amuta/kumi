# Kumi

A Ruby library for building business rule systems. Kumi compiles declarative rules into dependency graphs with static analysis and type checking.

## What is Kumi?

Kumi helps you organize complex business logic in a structured way:
- Define rules declaratively using a Ruby DSL
- Automatic dependency resolution between rules
- Type checking for rule inputs and outputs
- Schema compilation to executable code
- AST-based design for extensibility

The core strength is the compiler architecture - rules are parsed into an AST, analyzed through multiple passes, then "compiled" to executable form. This foundation enables building various frontends and backends.

## Installation

```bash
gem install kumi
```

Or add to your Gemfile:

```ruby
gem 'kumi'
```

## Basic Usage

```ruby
require 'kumi'

# Define a schema with business rules
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
  
  def self.calculate(customer_data)
    from(customer_data).fetch(:final_discount)
  end
end

# Use it
discount = DiscountCalculator.calculate({
  score: 75, 
  base_discount: 10.0, 
  customer_tier: "premium"
})
# => 15.0
```

Kumi can also be used functionally:

```ruby
schema = Kumi.schema do
  # same schema definition
end

runner = schema.runner
result = runner.fetch(:final_discount, data)
```

## How It Works

### Input Declaration
Schemas start by declaring expected input fields:

```ruby
input do
  key :age, type: :integer
  key :name, type: :string
  key :scores, type: array(:float)
end
```

### Rule Definitions
Define business logic using predicates and values:

```ruby
predicate :adult, fn(:>=, input.age, 18)
value :greeting, fn(:concat, "Hello, ", input.name)
value :average_score, fn(:divide, fn(:sum, input.scores), fn(:size, input.scores))
```

### Dependencies and Evaluation
Rules can reference other rules, creating a dependency graph:

```ruby
predicate :eligible, fn(:and, ref(:adult), fn(:>, ref(:average_score), 75))
value :status, fn(:conditional, ref(:eligible), "approved", "rejected")
```

Kumi automatically determines evaluation order and detects circular dependencies.

### Type System
- Input types can be declared explicitly
- Expression types are inferred automatically
- Type compatibility is checked at schema compilation
- Supports primitives and collections: `array(:type)`, `hash(:key_type, :value_type)`

## Examples

### Loan Approval Rules
```ruby
class LoanApproval
  extend Kumi::Schema
  
  schema do
    input do
      key :credit_score, type: :integer
      key :annual_income, type: :float
      key :loan_amount, type: :float
      key :employment_years, type: :integer
    end
    
    predicate :good_credit, fn(:>=, input.credit_score, 700)
    predicate :stable_employment, fn(:>=, input.employment_years, 2)
    
    value :debt_ratio, fn(:divide, input.loan_amount, input.annual_income)
    predicate :manageable_debt, fn(:<, ref(:debt_ratio), 0.4)
    
    value :approval_status do
      on :good_credit, :stable_employment, :manageable_debt, "approved"
      on :good_credit, :manageable_debt, "conditional"
      base "denied"
    end
  end
  
  def self.evaluate(application)
    from(application).fetch(:approval_status)
  end
end
```

### Dynamic Pricing
```ruby
class PricingEngine
  extend Kumi::Schema
  
  schema do
    input do
      key :base_price, type: :float
      key :customer_tier, type: :string
      key :quantity, type: :integer
      key :demand_level, type: :string
    end
    
    predicate :bulk_order, fn(:>=, input.quantity, 20)
    predicate :premium_customer, fn(:==, input.customer_tier, "premium")
    predicate :high_demand, fn(:==, input.demand_level, "high")
    
    value :volume_discount, fn(:conditional, ref(:bulk_order), 0.15, 0.0)
    value :tier_discount, fn(:conditional, ref(:premium_customer), 0.10, 0.0)
    value :demand_multiplier, fn(:conditional, ref(:high_demand), 1.2, 1.0)
    
    value :total_discount, fn(:add, ref(:volume_discount), ref(:tier_discount))
    value :discounted_price, fn(:multiply, input.base_price, fn(:subtract, 1.0, ref(:total_discount)))
    value :final_price, fn(:multiply, ref(:discounted_price), ref(:demand_multiplier))
  end
  
  def self.calculate(params)
    from(params).fetch(:final_price)
  end
end
```

## Design

### AST Foundation
Kumi compiles schemas through several phases:

1. **Parse** - DSL to syntax tree (AST)
2. **Analyze** - Multi-pass validation and dependency resolution  
3. **Compile** - AST to executable functions

This architecture enables:
- Different input syntaxes (Ruby DSL, YAML, JSON)
- Rule storage in databases or external systems
- API-driven rule management
- Custom analysis passes

### Extensibility
The AST-based design allows building tools on top of Kumi:

```ruby
# Potential extensions
ast = schema.analysis.syntax_tree
rules_json = ASTSerializer.to_json(ast)
yaml_schema = ASTExporter.to_yaml(ast) 
visual_graph = DependencyVisualizer.render(ast)
```

Since Kumi is MIT licensed, you can extend it for specific needs without restrictions.

## Analysis Passes

Kumi's multi-pass analyzer ensures schema correctness:

1. **Name Indexing** - Find declarations, check duplicates
2. **Input Collection** - Gather field metadata  
3. **Definition Validation** - Validate structure
4. **Dependency Resolution** - Build dependency graph
5. **Cycle Detection** - Find circular dependencies
6. **Topological Sorting** - Create evaluation order
7. **Type Inference** - Infer expression types
8. **Type Checking** - Validate compatibility

## Development

```bash
bundle install        # Install dependencies
bundle exec rspec     # Run tests
bundle exec rubocop   # Run linter
rake                  # Run tests and linter
```

## Examples

See `examples/input_block_typing_showcase.rb` for comprehensive usage examples.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass: `bundle exec rspec`
5. Ensure code style compliance: `bundle exec rubocop`
6. Submit a pull request

## License

MIT License - see LICENSE file for details.
