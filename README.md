# Kumi

**Kumi** is a sophisticated trait engine that transforms complex business logic into a declarative dependency graph, compiles it into efficient Ruby lambdas, and provides rich evaluation capabilities. It's not just a DSL—it's a complete computational graph system with advanced analysis, optimization, and execution features.

## What is Kumi?

Kumi is a **declarative dependency graph engine** that replaces imperative business logic with a powerful trait system. It's designed for scenarios where you need to:

- **Build Complex Business Rules**: Express intricate interdependencies between data, traits, and derived attributes
- **Create Decision Tables**: Implement multi-condition logic with cascading rules and fallbacks
- **Optimize Performance**: Compile business logic into efficient, reusable functions
- **Handle Complex Dependencies**: Automatically resolve and validate complex dependency graphs
- **Enable Partial Evaluation**: Evaluate only what you need for performance optimization

## The Power of the Trait System

Kumi's trait system creates a **computational graph** where:

- **Nodes** are traits, attributes, and functions
- **Edges** are dependencies (references between definitions)
- **Resolution** happens through lazy evaluation with memoization
- **Compilation** transforms the graph into efficient Ruby lambdas

This enables behaviors that would be extremely complex to implement manually:

### Complex Interdependencies
```ruby
schema = Kumi::Parser::Dsl.schema do
  # Base traits from raw data
  trait :adult, key(:age), :>=, 18
  trait :high_balance, key(:account_balance), :>=, 10_000
  trait :recent_activity, key(:last_purchase_days_ago), :<=, 30
  trait :frequent_buyer, key(:total_purchases), :>=, 50

  # Helper functions that combine multiple conditions
  attribute :check_engagement, fn(:all?, [ref(:recent_activity), ref(:frequent_buyer)])
  attribute :check_value, fn(:all?, [ref(:high_balance), ref(:long_term_customer)])

  # Derived traits that reference helper functions
  trait :engaged_customer, ref(:check_engagement), :==, true
  trait :valuable_customer, ref(:check_value), :==, true

  # Complex attributes with cascading logic
  attribute :customer_tier do
    on :valuable_customer, :engaged_customer, "Gold"
    on :high_balance, "Premium"
    on :adult, "Standard"
    else "Basic"
  end

  # Attributes that combine multiple data sources
  attribute :engagement_score, fn(:multiply,
    key(:total_purchases),
    fn(:conditional, ref(:engaged_customer), 1.5, 1.0)
  )
end
```

## Key Features

### 🎯 **Declarative Dependency Graph**
Define complex business logic as a graph of interdependent traits and attributes. The system automatically:
- **Detects cycles** in your dependency graph
- **Validates references** to ensure all dependencies exist
- **Computes optimal evaluation order** using topological sorting
- **Builds a complete dependency map** for analysis and optimization

### ⚡ **Sophisticated Compilation Pipeline**
Kumi doesn't just interpret—it compiles your schema into efficient Ruby lambdas:

1. **Parsing**: DSL blocks → Abstract Syntax Tree (AST)
2. **Analysis**: Dependency analysis, cycle detection, validation
3. **Compilation**: AST → Executable Ruby lambdas
4. **Execution**: Fast evaluation with lazy resolution

### 🔄 **Rich Evaluation Modes**
Evaluate exactly what you need:

```ruby
# Full evaluation
result = compiled.evaluate(data)

# Only traits (for performance)
traits_only = compiled.traits(data)

# Only attributes
attributes_only = compiled.attributes(data)

# Single binding (for targeted computation)
tier = compiled.evaluate_binding(:customer_tier, data)
```

### 🎛️ **Extensible Function System**
Register custom Ruby functions that integrate seamlessly with comprehensive core operations:

```ruby
# Core operations automatically available
# Math: add, subtract, multiply, divide, modulo, power, abs, round, floor, ceil
# String: concat, upcase, downcase, capitalize, strip, length, include?, start_with?, end_with?
# Logical: and, or, not, all?, any?, none?
# Collections: size, empty?, first, last, sum, max, min, sort, reverse, uniq
# Conditionals: conditional, if, coalesce, else
# Types: to_string, to_integer, to_float, to_boolean, to_array

# Register custom functions
Kumi::FunctionRegistry.register(:calculate_bonus) do |years, is_vip, engagement|
  base = years * 10
  base *= 2 if is_vip
  (base * (engagement / 100.0)).round(2)
end

# Auto-register functions from modules
module BusinessLogic
  def self.calculate_tax(amount, rate = 0.1)
    amount * rate
  end
end

Kumi::FunctionRegistry.auto_register("BusinessLogic", prefix: "business")

# Use in schema with full type safety
attribute :bonus, fn(:calculate_bonus, 
  key(:years_customer), 
  ref(:vip), 
  ref(:engagement_score)
)
attribute :tax, fn(:business_calculate_tax, ref(:total_amount))
```

### 📊 **Advanced Decision Tables**
Implement complex multi-condition logic with cascading rules:

```ruby
attribute :segment do
  on :high_value, :loyal, "VIP"
  on :high_value, :engaged, "Champion"
  on :high_value, "High Value"
  on :engaged, "Loyal"
  else "Standard"
end
```

### 🔍 **Comprehensive Analysis**
The analyzer provides multiple passes that work together:

- **NameIndexer**: Builds definition index, detects duplicates
- **TypeValidator**: Validates types, builds dependency graph, collects leaves
- **CycleDetector**: Detects cyclic dependencies in the graph
- **Toposorter**: Computes optimal evaluation order

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'kumi'
```

And then execute:

```sh
bundle install
```

Or install it yourself as:

```sh
gem install kumi
```

## Quick Start

### Basic Usage

```ruby
require "kumi"

# Define a schema with traits and attributes
schema = Kumi::Parser::Dsl.schema do
  # Define traits (boolean conditions)
  trait :adult, key(:age), :>=, 18
  trait :vip, key(:status), :==, "VIP"
  trait :high_value, key(:balance), :>=, 10_000

  # Define attributes (derived values)
  attribute :customer_tier do
    on :vip, :high_value, "VIP"
    on :adult, "Adult"
    else "Standard"
  end

  attribute :greeting, fn(:concat, [
    "Hello ",
    key(:name),
    "!"
  ])
end

# Compile and evaluate
analyzer_result = Kumi::Analyzer.analyze!(schema)
compiled = Kumi::Compiler.compile(schema, analyzer: analyzer_result)

data = { name: "Alice", age: 30, status: "VIP", balance: 15_000 }
result = compiled.evaluate(data)

puts result[:traits][:adult]           # => true
puts result[:traits][:vip]             # => true
puts result[:attributes][:customer_tier] # => "VIP"
puts result[:attributes][:greeting]    # => "Hello Alice!"
```

### Advanced Customer Segmentation

```ruby
# Register custom functions
Kumi::FunctionRegistry.register(:all?) { |conditions| conditions.all? }
Kumi::FunctionRegistry.register(:concat) { |*strings| strings.join }
Kumi::FunctionRegistry.register(:multiply) { |a, b| a * b }

schema = Kumi::Parser::Dsl.schema do
  # Base traits from raw data
  trait :adult, key(:age), :>=, 18
  trait :high_balance, key(:account_balance), :>=, 10_000
  trait :recent_activity, key(:last_purchase_days_ago), :<=, 30
  trait :frequent_buyer, key(:total_purchases), :>=, 50

  # Helper functions for complex logic
  attribute :check_engagement, fn(:all?, [ref(:recent_activity), ref(:frequent_buyer)])
  attribute :check_value, fn(:all?, [ref(:high_balance), ref(:long_term_customer)])

  # Derived traits using helper functions
  trait :engaged_customer, ref(:check_engagement), :==, true
  trait :valuable_customer, ref(:check_value), :==, true

  # Complex attributes with cascading logic
  attribute :customer_tier do
    on :valuable_customer, :engaged_customer, "Gold"
    on :high_balance, "Premium"
    on :adult, "Standard"
    else "Basic"
  end

  # Attributes combining multiple data sources
  attribute :engagement_score, fn(:multiply,
    key(:total_purchases),
    fn(:conditional, ref(:engaged_customer), 1.5, 1.0)
  )
end
```

## Core Concepts

### Traits
Named boolean expressions that can reference other traits or raw data:

```ruby
trait :adult, key(:age), :>=, 18
trait :vip, key(:status), :==, "VIP"
trait :engaged, ref(:recent_activity), :==, true
```

### Attributes
Named values that can use traits, fields, functions, or cascades:

```ruby
# Simple field reference
attribute :name, key(:first_name)

# Function call
attribute :greeting, fn(:concat, ["Hello ", key(:name)])

# Cascade (decision table)
attribute :tier do
  on :vip, "VIP"
  on :adult, "Adult"
  else "Standard"
end
```

### Cascade Expressions
Decision tables for multi-condition logic:

```ruby
attribute :segment do
  on :high_value, :loyal, "VIP"
  on :high_value, "High Value"
  on :loyal, "Loyal"
  else "Standard"
end
```

### Custom Functions
Register your own Ruby functions:

```ruby
Kumi::FunctionRegistry.register(:calculate_bonus) do |years, is_vip|
  base = years * 10
  is_vip ? base * 2 : base
end

# Use in schema
attribute :bonus, fn(:calculate_bonus, key(:years_customer), ref(:vip))
```

## Advanced Features

### Partial Evaluation

```ruby
# Evaluate only traits
traits_only = compiled.traits(data)

# Evaluate only attributes
attributes_only = compiled.attributes(data)

# Evaluate single binding
tier = compiled.evaluate_binding(:customer_tier, data)
```

### Class Integration

```ruby
class CustomerSegmenter
  extend Kumi::Parser::Dsl

  schema do
    trait :vip, key(:status), :==, "VIP"
    attribute :tier do
      on :vip, "VIP"
      else "Standard"
    end
  end

  def segment(customer_data)
    analyzer_result = Kumi::Analyzer.analyze!(generated_schema)
    compiled = Kumi::Compiler.compile(generated_schema, analyzer: analyzer_result)
    compiled.evaluate(customer_data)
  end
end
```

### Error Handling

Kumi provides detailed error messages for:

- **Syntax Errors**: Invalid DSL syntax with file and line numbers
- **Semantic Errors**: Undefined references, cyclic dependencies
- **Runtime Errors**: Missing fields, function errors with context

```ruby
# Clear error messages
begin
  schema = Kumi::Parser::Dsl.schema do
    attribute :name, ref(:undefined_trait)
  end
  analyzer_result = Kumi::Analyzer.analyze!(schema)
rescue Kumi::Errors::SemanticError => e
  puts e.message # "at schema.rb:2: undefined reference to `undefined_trait`"
end
```

## Performance Characteristics

### Compilation vs Execution
Schemas are compiled once into efficient Ruby lambdas, then executed multiple times:

```ruby
# Expensive: Compilation (happens once)
analyzer_result = Kumi::Analyzer.analyze!(schema)
compiled = Kumi::Compiler.compile(schema, analyzer: analyzer_result)

# Fast: Execution (happens many times)
result1 = compiled.evaluate(customer_data_1)
result2 = compiled.evaluate(customer_data_2)
result3 = compiled.evaluate(customer_data_3)
```

### Dependency Optimization
The compiler automatically determines the optimal evaluation order using topological sorting, ensuring dependencies are resolved efficiently.

### Lazy Resolution
The system uses lazy evaluation with memoization, computing values only when needed and caching results for subsequent access.

## Use Cases

### Customer Segmentation
Classify customers based on behavior, demographics, and transaction history with complex interdependencies.

### Business Rules Engine
Apply complex business logic to data with clear, maintainable rules that can reference each other.

### Data Transformation
Derive new attributes from existing data with complex interdependencies and cascading logic.

### Decision Tables
Implement multi-condition logic with cascading rules and fallbacks.

### Performance-Critical Applications
Compile business logic into efficient, reusable functions for high-throughput scenarios.

## Architecture

### Compilation Pipeline
1. **Parsing**: DSL blocks are parsed into an Abstract Syntax Tree (AST)
2. **Analysis**: Dependencies are analyzed, cycles detected, and validation performed
3. **Compilation**: AST is compiled into executable Ruby lambdas
4. **Execution**: Compiled schemas efficiently evaluate data with lazy resolution

### Analysis Passes
- **NameIndexer**: Builds definition index and detects duplicates
- **TypeValidator**: Validates types and builds dependency graph
- **CycleDetector**: Detects cyclic dependencies
- **Toposorter**: Computes optimal evaluation order

### Computational Graph
The system creates a directed acyclic graph where:
- **Nodes** represent traits, attributes, and functions
- **Edges** represent dependencies between definitions
- **Evaluation** follows the topological order for optimal performance
- **Caching** ensures each node is computed only once per evaluation

## Development

### Requirements
- Ruby 3.0+
- Zeitwerk for autoloading

### Running Tests

```sh
bundle exec rspec
```

### Interactive Console

```sh
bin/console
```

## License

MIT License © André Muta

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Create a new Pull Request

---

**Kumi** transforms complex business logic into a declarative dependency graph that's compiled into efficient, maintainable code. Whether you're building customer segmentation systems, business rules engines, or data transformation pipelines, Kumi provides the tools you need to express complex logic declaratively while maintaining performance and enabling sophisticated behaviors that would be extremely complex to implement manually.

```ruby
# quick teaser
require "kumi"
# schema = Kumi::DSL.build do ... end
# trait-engine
