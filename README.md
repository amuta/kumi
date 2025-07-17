# Kumi

A declarative decision-modeling compiler for Ruby that transforms complex business rules into executable dependency graphs.

## Overview

Kumi analyzes rule interdependencies, validates cycles, detects redundant rules, and generates optimized evaluation functions for sophisticated decision logic.

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

# Define a schema with business rules
result = Kumi.schema do
  predicate :high_risk, fn(:>, key(:score), 80)
  value :discount, cascade do
    on ref(:high_risk), 0
    else fn(:multiply, key(:base_discount), 1.2)
  end
end

# Execute with input data
runner = result.runner
puts runner.fetch(:discount, score: 75, base_discount: 10) # => 12.0
```

## DSL Syntax

- `predicate :name, expression` - Boolean conditions
- `value :name, expression` - Computed values  
- `cascade :name do ... end` - Conditional logic
- `key(:field)` - Access input data
- `ref(:name)` - Reference other declarations
- `fn(:function, args...)` - Function calls

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop

# Build gem
gem build kumi.gemspec
```
