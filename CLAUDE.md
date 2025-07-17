# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kumi is a declarative decision-modeling compiler for Ruby that transforms complex business rules into executable dependency graphs. It analyzes rule interdependencies, validates cycles, detects redundant rules, and generates optimized evaluation functions for sophisticated decision logic.

## Development Commands

### Testing
- `bundle exec rspec` - Run all tests
- `bundle exec rspec spec/path/to/specific_spec.rb` - Run specific test file
- `bundle exec rspec spec/path/to/specific_spec.rb:123` - Run specific test at line

### Linting & Code Quality
- `bundle exec rubocop` - Run RuboCop linter
- `bundle exec rubocop -a` - Auto-fix RuboCop issues where possible
- `rake` - Run default task (includes rspec and rubocop)

### Gem Management
- `bundle install` - Install dependencies
- `gem build kumi.gemspec` - Build the gem
- `gem install ./kumi-*.gem` - Install locally built gem

## Architecture Overview

### Core Components

**Schema System** (`lib/kumi/schema.rb`):
- Entry point that ties together parsing, analysis, and compilation
- Provides the `schema(&block)` DSL method that builds the syntax tree, runs analysis, and compiles to executable form
- Generates a `Runner` instance for executing queries against input data

**Parser** (`lib/kumi/parser/`):
- `dsl.rb` - Main DSL parser that converts Ruby block syntax into AST nodes
- `dsl_builder_context.rb` - Context for building DSL elements
- `dsl_cascade_builder.rb` - Specialized builder for cascade expressions
- `dsl_proxy.rb` - Proxy object for method delegation during parsing

**Syntax Tree** (`lib/kumi/syntax/`):
- `node.rb` - Base node class with location tracking
- `root.rb` - Root schema node containing attributes and traits
- `declarations.rb` - Attribute and trait declaration nodes  
- `expressions.rb` - Expression nodes (calls, lists, cascades)
- `terminal_expressions.rb` - Terminal nodes (literals, fields, bindings)

**Analyzer** (`lib/kumi/analyzer.rb`):
- Multi-pass analysis system that validates schemas and builds dependency graphs
- **Pass 1**: `name_indexer.rb` - Find all names, check for duplicates
- **Pass 2**: `definition_validator.rb` - Validate basic structure
- **Pass 3**: `dependency_resolver.rb` - Build dependency graph
- **Pass 4**: `type_checker.rb` - Validate function types  
- **Pass 5**: `cycle_detector.rb` - Find circular dependencies
- **Pass 6**: `toposorter.rb` - Create evaluation order

**Compiler** (`lib/kumi/compiler.rb`):
- Transforms analyzed syntax tree into executable lambda functions
- Maps each expression type to a compilation method
- Handles function calls via `FunctionRegistry`
- Produces `CompiledSchema` with executable bindings

**Function Registry** (`lib/kumi/function_registry.rb`):
- Registry of available functions (operators, math, string, logical, collection operations)
- Supports custom function registration with metadata
- Core functions include: `==`, `>`, `<`, `add`, `multiply`, `and`, `or`, `clamp`, etc.

**Runner** (`lib/kumi/runner.rb`):
- Executes compiled schemas against input data
- Provides `fetch(key)` for individual value retrieval with caching
- Provides `slice(*keys)` for batch evaluation
- Provides `explain(key)` for detailed execution tracing

### Key Patterns

**DSL Structure**:
```ruby
schema do
  predicate :name, expression    # Boolean conditions
  value :name, expression        # Computed values  
  cascade :name do               # Conditional logic
    on condition, result
    else default
  end
end
```

**Expression Types**:
- `key(:field)` - Access input data
- `ref(:name)` - Reference other declarations
- `fn(:name, args...)` - Function calls
- `[element1, element2]` - Lists
- Literals (numbers, strings, booleans)

**Analysis Flow**:
1. Parse DSL → Syntax Tree
2. Analyze Syntax Tree → Analysis Result (dependency graph, topo order)
3. Compile → Executable Schema
4. Execute with Runner

### Examples Directory

The `examples/` directory contains comprehensive examples showing Kumi usage patterns:
- `fraud_risk_scorer.rb` - Complex fraud detection rules (extensive example)
- `federal_tax_calculator.rb` - Tax calculation logic
- `function_registry_demo.rb` - Custom function examples

## Test Structure

- `spec/kumi/` - Unit tests for core components
- `spec/integration/` - Integration tests for full workflows
- `spec/fixtures/` - Test fixtures and sample schemas
- `spec/support/` - Test helpers (`ast_factory.rb`, `schema_generator.rb`)

## Key Files for Understanding

1. `lib/kumi/schema.rb` - Start here to understand the main API
2. `examples/fraud_risk_scorer.rb` - Comprehensive real-world example
3. `lib/kumi/analyzer.rb` - Core analysis pipeline
4. `lib/kumi/function_registry.rb` - Available functions and extension patterns
5. `spec/integration/compiler_integration_spec.rb` - End-to-end test examples