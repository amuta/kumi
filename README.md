# Kumi: A Declarative Business Logic Compiler

Kumi provides a DSL for defining, validating, and executing complex business logic. It parses declarative rules into an Abstract Syntax Tree (AST), runs a series of analysis passes, and compiles the result into an executable dependency graph.

This approach isolates business logic from application code, allowing it to be managed and validated as a self-contained unit.

## Installation

Add this line to your application's Gemfile:
```ruby
gem 'kumi'
```
And then execute `bundle install`.

## Basic Usage

A schema is defined using the `Kumi::Schema` module. The following example implements a simple discount calculator.

```ruby
require 'kumi'

class DiscountCalculator
  extend Kumi::Schema
  
  schema do
    # 1. Declare the expected inputs and their types.
    input do
      key :score, type: :integer
      key :base_discount, type: :float
      key :customer_tier, type: :string
    end
    
    # 2. Define intermediate logic using predicates.
    predicate :high_risk, fn(:>, input.score, 80)
    predicate :premium_customer, fn(:==, input.customer_tier, "premium")
    
    # 3. Define values that depend on inputs or other rules.
    value :discount_multiplier do
      on :premium_customer, 1.5
      on :high_risk, 0.8
      base 1.2
    end
      
    # 4. Define the final output value.
    value :final_discount, fn(:multiply, input.base_discount, ref(:discount_multiplier))
  end
  
  # 5. Create an interface to execute the schema.
  def self.calculate(customer_data)
    from(customer_data).fetch(:final_discount)
  end
end

# Execute the schema with a given set of inputs.
discount = DiscountCalculator.calculate({
  score: 75, 
  base_discount: 10.0, 
  customer_tier: "premium"
})
# => 15.0
```

## Debugging a Schema
Standard debugging tools cannot be used inside a `schema` block because the DSL is declarative and does not execute code linearly. To inspect the intermediate values of the dependency graph, use the `runner`.

The runner's `fetch` method can retrieve the calculated value of any named `predicate` or `value`.

```ruby
# Get the runner for the schema.
runner = DiscountCalculator.runner

# Prepare the input data.
customer_data = { score: 90, base_discount: 10.0, customer_tier: "standard" }

# Fetch intermediate values by name.
runner.fetch(:high_risk, customer_data)            # => true
runner.fetch(:premium_customer, customer_data)     # => false
runner.fetch(:discount_multiplier, customer_data)  # => 0.8

# Fetch the final value.
runner.fetch(:final_discount, customer_data)       # => 8.0
```

## Core Architecture

### 1. The Compiler Pipeline
Kumi processes schemas in three stages:

1.  **Parse:** The Ruby DSL is parsed into an **Abstract Syntax Tree (AST)**. The AST is a language-agnostic data structure representing the rules.
2.  **Analyze:** A series of validation passes are executed on the AST. These passes perform dependency resolution, cycle detection, and type checking.
3.  **Compile:** The validated AST is transformed into an executable object graph.

This decoupled pipeline allows the analysis and compilation logic to be reused for different input formats.

### 2. The Type System
Kumi includes a static type system to validate data compatibility.
- **Explicit Types:** Input types can be declared with primitives (`:integer`, `:string`) and collections (`array(:float)`).
- **Inferred Types:** The return types of functions and expressions are inferred by the `TypeInferencer` pass.
- **Type Checking:** The `TypeChecker` pass validates that operations are performed on compatible types.

### 3. AST Serialization
The AST can be serialized to and from JSON. This allows schemas to be stored in databases or managed via APIs.

```ruby
# Export a schema's AST to a JSON string.
json_representation = Kumi::Export.to_json(DiscountCalculator.schema_definition)

# Import the AST from JSON.
imported_ast = Kumi::Export.from_json(json_representation)

# The imported AST can be compiled and executed.
runner = Kumi::Compiler.compile(imported_ast).runner
runner.fetch(:final_discount, { score: 75, base_discount: 10.0, customer_tier: "premium" })
# => 15.0
```

## Extending the DSL with Custom Functions
The function set is extensible. Custom functions can be registered and used within a schema.

```ruby
# 1. Define custom functions in a module.
module MyCustomFunctions
  def self.calculate_risk_score(credit_score, num_transactions)
    (credit_score * 0.7) + (num_transactions * 0.3)
  end
end

# 2. Create a new function registry and register the module.
registry = Kumi::FunctionRegistry.new
registry.register_module(MyCustomFunctions)

# 3. Provide the registry to the compiler.
compiler = Kumi::Compiler.new(function_registry: registry)
runner = compiler.compile(MySchema).runner

# 4. The function is now available in any schema using this compiler instance.
#
# schema MySchema do
#   ...
#   value :risk_score, fn(:calculate_risk_score, input.credit_score, input.num_transactions)
#   ...
# end
```

## Building Custom Tooling
The decoupled AST enables the development of custom tools that operate on schemas. Examples include:
- Documentation generators.
- Dependency graph visualizers.
- Linters for enforcing schema conventions.

## Common Use Cases
This structure is suited for implementing stateless, declarative logic systems such as:
- Financial modeling (underwriting, fraud detection).
- E-commerce pricing and promotions.
- Workflow automation (lead scoring, access control).

## Development

```bash
bundle install        # Install dependencies
bundle exec rspec     # Run tests
bundle exec rubocop   # Run linter
rake                  # Run tests and linter
```

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).