# Kumi: A Declarative Business Logic Compiler

Kumi provides a DSL for defining, validating, and executing complex business logic. It parses declarative rules into an Abstract Syntax Tree (AST), runs a series of analysis passes, and builds an executable dependency graph (of procs).

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
    # 1. Declare inputs with type-specific methods and validation constraints
    input do
      integer :score, domain: 0..1000                    # Score must be 0-1000
      float   :base_discount, domain: 0.0..1.0          # Discount rate 0-100%
      string  :customer_tier, domain: %w[basic premium gold platinum]
      boolean :is_active, domain: [true]                # Must be active
      array   :transaction_history, elem: { type: :float }
    end
    
    # 2. Define intermediate logic using traits
    trait :high_risk, (input.score > 80)
    trait :premium_customer, (input.customer_tier == "premium")
    trait :eligible, (ref(:premium_customer) & input.is_active)
    
    # 3. Define values that depend on inputs or other rules
    value :discount_multiplier do
      on :eligible, 1.5
      on :high_risk, 0.8
      base 1.2
    end
      
    # 4. Define the final output value
    value :final_discount, fn(:multiply, input.base_discount, ref(:discount_multiplier))
  end
  
  # 5. Create an interface to execute the schema
  def self.calculate(customer_data)
    from(customer_data).fetch(:final_discount)
  end
end

# Execute the schema with valid inputs
discount = DiscountCalculator.calculate({
  score: 75,
  base_discount: 0.10,
  customer_tier: "premium",
  is_active: true,
  transaction_history: [100.0, 250.5, 75.0]
})
# => 0.15 (10% base * 1.5 multiplier)

# Validation errors are caught automatically
begin
  DiscountCalculator.calculate({
    score: 1500,              # Outside domain 0..1000
    base_discount: 1.5,       # Outside domain 0.0..1.0  
    customer_tier: "unknown", # Not in allowed values
    is_active: false,         # Must be true
    transaction_history: ["invalid", 100.0] # Array contains non-float
  })
rescue Kumi::Errors::InputValidationError => e
  puts e.message
  # Multiple validation errors:
  # Type violations:
  #   - Field :transaction_history expected array(float), got ["invalid", 100.0] of type array(mixed)
  # Domain violations:
  #   - Field :score value 1500 is outside domain 0..1000
  #   - Field :base_discount value 1.5 is outside domain 0.0..1.0
  #   - Field :customer_tier value "unknown" is not in allowed values ["basic", "premium", "gold", "platinum"]
  #   - Field :is_active value false is not in allowed values [true]
end
```

## Enhanced Input Declaration Syntax

Kumi provides intuitive type-specific methods for declaring inputs with built-in validation:

### Type-Specific Declaration Methods

```ruby
schema do
  input do
    # Primitive types with clean syntax
    integer :user_id                           # Any integer
    float   :temperature, domain: -50.0..50.0 # Constrained range
    string  :status, domain: %w[active inactive suspended]
    boolean :verified                          # true or false
    
    # Collection types with element specifications
    array :scores                              # Array of any type
    array :grades, elem: { type: :float }      # Array of floats only
    hash  :settings                            # Hash with any keys/values
    hash  :config, key: { type: :string }, val: { type: :integer }
    
    # Backward compatibility - legacy syntax still works
    key :legacy_field, type: :string, domain: %w[old style]
  end
  
  # Access declared fields via input.field_name
  trait :high_score, (fn(:>, input.scores, [90.0, 85.0, 95.0]))
  value :max_score, fn(:max, input.scores)
end
```

### Advanced Validation Features

```ruby
# Custom validation with Proc domains
schema do
  input do
    string :email, domain: ->(email) { 
      email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i) 
    }
    
    string :password, domain: ->(pwd) { 
      pwd.length >= 8 && pwd.match?(/[A-Z]/) && pwd.match?(/[0-9]/) 
    }
    
    # Exclusive ranges (excludes end value)
    float :probability, domain: 0.0...1.0  # 0.0 <= x < 1.0
    
    # Complex nested structures
    array :users, elem: { 
      type: hash(:string, :any)  # Array of string-keyed hashes
    }
    
    hash :metrics, key: { type: :string }, val: { 
      type: array(:float)  # Hash mapping strings to float arrays
    }
  end
  
  trait :valid_user, (input.email != "")
  value :user_count, fn(:size, input.users)
end
```

### Real-World Example: E-commerce Pricing

```ruby
class PricingEngine
  extend Kumi::Schema
  
  schema do
    input do
      # Product information
      integer :product_id, domain: 1..999_999
      float   :base_price, domain: 0.01..10_000.0
      string  :category, domain: %w[electronics clothing books home sports]
      
      # Customer information  
      string  :customer_tier, domain: %w[bronze silver gold platinum]
      integer :loyalty_points, domain: 0..100_000
      boolean :is_member
      
      # Order details
      integer :quantity, domain: 1..100
      array   :coupon_codes, elem: { type: :string }
      hash    :shipping_info, key: { type: :string }, val: { type: :string }
      
      # Seasonal factors
      float   :seasonal_multiplier, domain: 0.5..2.0
    end
    
    # Business logic traits
    trait :bulk_order, (input.quantity >= 10)
    trait :premium_customer, (fn(:in, input.customer_tier, %w[gold platinum]))
    trait :loyalty_eligible, (input.loyalty_points > 1000)
    trait :free_shipping_eligible, (ref(:premium_customer) & ref(:bulk_order))
    
    # Pricing calculations
    value :base_total, fn(:multiply, input.base_price, input.quantity)
    
    value :discount_rate do
      on fn(:and, ref(:premium_customer), ref(:loyalty_eligible)), 0.25
      on ref(:premium_customer), 0.15  
      on ref(:bulk_order), 0.10
      on input.is_member, 0.05
      base 0.0
    end
    
    value :discounted_total, fn(:multiply, 
      ref(:base_total), 
      fn(:subtract, 1.0, ref(:discount_rate))
    )
    
    value :seasonal_price, fn(:multiply, 
      ref(:discounted_total), 
      input.seasonal_multiplier
    )
    
    value :shipping_cost do
      on ref(:free_shipping_eligible), 0.0
      on fn(:>, ref(:seasonal_price), 100.0), 0.0
      base 9.99
    end
    
    value :final_price, fn(:add, ref(:seasonal_price), ref(:shipping_cost))
  end
  
  def self.calculate_price(order_data)
    runner = from(order_data)
    {
      base_total: runner.fetch(:base_total),
      discount_rate: runner.fetch(:discount_rate),
      seasonal_price: runner.fetch(:seasonal_price),
      shipping_cost: runner.fetch(:shipping_cost),
      final_price: runner.fetch(:final_price)
    }
  end
end

# Usage with automatic validation
result = PricingEngine.calculate_price({
  product_id: 12345,
  base_price: 29.99,
  category: "electronics",
  customer_tier: "gold",
  loyalty_points: 2500,
  is_member: true,
  quantity: 12,
  coupon_codes: ["SAVE10", "FREESHIP"],
  shipping_info: { "method" => "express", "address" => "123 Main St" },
  seasonal_multiplier: 1.2
})

puts result
# => {
#   base_total: 359.88,
#   discount_rate: 0.25,
#   seasonal_price: 323.892,
#   shipping_cost: 0.0,
#   final_price: 323.892
# }
```

## Errors at Schema Definition

When you define a `schema` block on a class (by extending `Kumi::Schema`), Kumi immediately
validates your DSL syntax and schema semantics as the class is loaded. This fail-fast approach
lets you catch mistakes early. Common failure scenarios include:

### Syntax errors
- **Missing expression or block for a value**
  ```ruby
  value :discount
  # => error: "value 'discount' requires an expression or a block at path/to/file.rb:42"
  ```
- **Invalid expression in a trait**
  ```ruby
  trait :flagged, (input.score >> 100)
  # => error: "undefined method `>>' for FieldRef at path/to/file.rb:87"
  ```

### Semantic errors
- **Duplicate definitions**
  ```ruby
  value :age, input.age
  value :age, input.birth_year
  # => error: "duplicate definition `age` at path/to/file.rb:56"
  ```
- **Cyclic dependencies**
  ```ruby
  value :a, ref(:b)
  value :b, ref(:a)
  # => error: "cycle detected: a → b → a"
  ```
- **Unsatisfiable logic**
  ```ruby
  trait :impossible, ((input.x > 10) & (input.x < 5))
  # => error: "unsatisfiable conditions for `impossible`"
  ```

### Type and metadata errors
- **Type mismatch in inputs**
  ```ruby
  input do
    key :rate, type: :integer
  end
  # => error: "Field :rate expected integer, got \"high\" of type string"
  ```
- **Conflicting input declarations**
  ```ruby
  input do
    key :score, type: :integer
    key :score, type: :float
  end
  # => error: "conflicting type declarations for `score`: integer vs float"
  ```
- **Type errors in expressions**
  ```ruby
  value :average, fn(:divide, input.total, input.count)
  # => error: "argument 1 of `fn(:divide)` expects int | float, got \"foo\" of type string"
  ```

Schemas are validated and loaded at class definition time, so you get immediate actionable feedback
when something is amiss.

## Debugging a Schema
Standard debugging tools cannot be used inside a `schema` block because the DSL is declarative and does not execute code linearly. To inspect the intermediate values of the dependency graph, use the `runner`.

The runner's `fetch` method can retrieve the calculated value of any named `trait` or `value`.

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
3.  **Build:** The validated AST is transformed into an executable object graph (dependency procs).

This decoupled pipeline allows the analysis and compilation logic to be reused for different input formats.

### 2. The Type System
Kumi includes a comprehensive static type system with runtime validation.
- **Type-Specific DSL:** Input types are declared with intuitive methods (`integer`, `float`, `string`, `boolean`, `array`, `hash`).
- **Domain Constraints:** Fields support range, enumeration, and custom proc validation (`domain: 0..100`, `domain: %w[a b c]`).
- **Runtime Validation:** Input data is automatically validated against declared types and constraints with detailed error messages.
- **Inferred Types:** The return types of functions and expressions are inferred by the `TypeInferencer` pass.
- **Type Checking:** The `TypeChecker` pass validates that operations are performed on compatible types.
- **Complex Types:** Support for nested structures like `array(hash(:string, :float))` with full validation.

### 3. AST Serialization
The AST can be serialized to and from JSON. This allows schemas to be stored in databases or managed via APIs.

```ruby
# Export a schema's AST to a JSON string.
json_representation = Kumi::Export.to_json(DiscountCalculator.schema_definition)

# Import the AST from JSON.
imported_ast = Kumi::Export.from_json(json_representation)

```
# The imported AST can be loaded and executed.
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
