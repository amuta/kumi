# Kumi

A Ruby library for building business rule systems. Kumi compiles declarative rules into dependency graphs with static analysis and type checking.

## What is Kumi?

Kumi helps you organize complex business logic in a structured way:
- Define rules declaratively using a Ruby DSL
- Automatic dependency resolution between rules
- Type checking for rule inputs and outputs
- Schema compilation to executable code
- AST-based design for extensibility

The core strength is the compiler architecture - rules are parsed into an AST, analyzed through multiple passes, then "compiled" to executable form.

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
    
    value :discount_multiplier do
      on :premium_customer, 1.5
      on :high_risk, 0.8, 
      base 1.2
    end
      
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
predicate :adult, input.age, :>=, 18
value :greeting, fn(:concat, "Hello, ", input.name)
value :average_score, fn(:divide, fn(:sum, input.scores), fn(:size, input.scores))
```

### Dependencies and Evaluation
Rules can reference other rules, creating a dependency graph:

```ruby
predicate :adult, input.age, :>=, 18
predicate :eligible, ref(:adult), :>, ref(:average_score)
value :status do
  on :adult, :eligible, "approved"
  base "rejected"
end
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

### Architecture

#### How it's organized
- The ruby DSL is parsed to an abstract syntax tree (AST)
- The syntax tree (AST) is decoupled from the analysis/compilation
- Data structures don't change after creation  
- No hidden state or complicated object relationships

#### How compilation works
Kumi compiles schemas in three steps:

1. **Parse** - Turn the DSL into a AST
2. **Analyze** - Validate the schema and figure out dependencies
3. **Compile** - Turn the syntax tree into runnable code


### Exporting Schemas

You can export schemas to JSON and import them back:

```ruby
# Export schema to JSON
json = Kumi::Export.to_json(schema)

# Import from JSON  
imported_schema = Kumi::Export.from_json(json)

# Imported schemas work the same as the originals
analysis = Kumi::Analyzer.analyze!(imported_schema)
compiled = Kumi::Compiler.compile(imported_schema, analyzer: analysis)
result = compiled.evaluate(data)
```

What it does:
- Export and import schemas without losing information
- Keeps Ruby types correct (symbols vs strings) when converting to JSON
- Handles complex structures like arrays, hashes, and nested expressions
- Can format JSON nicely for humans to read

This lets you:
- Store schemas in databases as JSON
- Build REST APIs for managing rules  
- Create web-based rule editors
- Share schemas between different services

### Building on top of Kumi
Since Kumi uses a syntax tree internally, you can build other tools:

```ruby
# Schema analysis and export
schema = MyBusinessRules.schema_definition
ast = schema.analysis.syntax_tree

# Export to various formats
json_schema = Kumi::Export.to_json(ast)
rules_api.store(schema_id, json_schema)

# Build custom tools
dependency_graph = schema.analysis.dependency_graph
visual_graph = DependencyVisualizer.render(dependency_graph)
docs = DocumentationGenerator.from_ast(ast)
```

## Analysis Passes

Kumi checks schemas in several passes to make sure they're correct:

1. **Name Indexing** - Find all declarations and check for duplicates
2. **Input Collection** - Collect information about input fields  
3. **Definition Validation** - Check that the structure makes sense
4. **Dependency Resolution** - Figure out which rules depend on others
5. **Cycle Detection** - Make sure there are no circular dependencies
6. **Topological Sorting** - Determine the order to evaluate rules
7. **Type Inference** - Figure out what types expressions return
8. **Type Checking** - Make sure types are compatible

## Development

```bash
bundle install        # Install dependencies
bundle exec rspec     # Run tests
bundle exec rubocop   # Run linter
rake                  # Run tests and linter
```

### Testing the Export System

The AST export system includes comprehensive integration tests:

```bash
# Test basic export/import functionality
bundle exec rspec spec/kumi/export_spec.rb

# Test analyzer integration with exported schemas  
bundle exec rspec spec/kumi/export/analyzer_integration_spec.rb

# Test comprehensive schema with all syntax features
bundle exec rspec spec/kumi/export/comprehensive_integration_spec.rb
```

These tests validate that exported schemas preserve semantic information and execute correctly after import.

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
