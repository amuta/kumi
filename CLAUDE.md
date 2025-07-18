# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kumi is a declarative decision-modeling compiler for Ruby that transforms complex business rules into executable dependency graphs. It features a multi-pass analyzer that validates rule interdependencies, detects cycles, infers types, and generates optimized evaluation functions. The system separates input field declarations from business logic through an explicit input block syntax.

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
- `dsl_builder_context.rb` - Context for building DSL elements with input/value/predicate methods
- `dsl_cascade_builder.rb` - Specialized builder for cascade expressions
- `dsl_proxy.rb` - Proxy object for method delegation during parsing
- `input_dsl_proxy.rb` - Proxy for input block DSL (only allows `key` declarations)
- `input_proxy.rb` - Proxy for `input.field_name` references in expressions

**Syntax Tree** (`lib/kumi/syntax/`):
- `node.rb` - Base node class with location tracking
- `root.rb` - Root schema node containing inputs, attributes, and traits
- `declarations.rb` - Attribute and trait declaration nodes  
- `expressions.rb` - Expression nodes (calls, lists, cascades)
- `terminal_expressions.rb` - Terminal nodes (literals, field references, bindings, field declarations)

**Analyzer** (`lib/kumi/analyzer.rb`):
- Multi-pass analysis system that validates schemas and builds dependency graphs
- **Pass 1**: `name_indexer.rb` - Find all names, check for duplicates
- **Pass 2**: `input_collector.rb` - Collect field metadata, validate conflicts
- **Pass 3**: `definition_validator.rb` - Validate basic structure
- **Pass 4**: `dependency_resolver.rb` - Build dependency graph
- **Pass 5**: `cycle_detector.rb` - Find circular dependencies
- **Pass 6**: `toposorter.rb` - Create evaluation order
- **Pass 7**: `type_inferencer.rb` - Infer types for all declarations
- **Pass 8**: `type_checker.rb` - Validate function types and compatibility using inferred types

**Compiler** (`lib/kumi/compiler.rb`):
- Transforms analyzed syntax tree into executable lambda functions
- Maps each expression type to a compilation method
- Handles function calls via `FunctionRegistry`
- Produces `CompiledSchema` with executable bindings

**Function Registry** (`lib/kumi/function_registry.rb`):
- Registry of available functions (operators, math, string, logical, collection operations)
- Supports custom function registration with comprehensive type metadata
- Each function includes param_types, return_type, arity, and description
- Core functions include: `==`, `>`, `<`, `add`, `multiply`, `and`, `or`, `clamp`, etc.
- Maintains backward compatibility with legacy type checking system

**Runner** (`lib/kumi/runner.rb`):
- Executes compiled schemas against input data
- Provides `fetch(key)` for individual value retrieval with caching
- Provides `slice(*keys)` for batch evaluation
- Provides `explain(key)` for detailed execution tracing

### Key Patterns

**DSL Structure**:
```ruby
schema do
  input do
    key :field_name, type: :string
    key :number_field, type: :integer, domain: 0..100
    key :scores, type: array(:float)
    key :metadata, type: hash(:string, :any)
  end
  
  predicate :name, expression    # Boolean conditions
  value :name, expression        # Computed values  
  value :name do               # Conditional logic
    on condition, result
    base default
  end
end
```

**Input Block System**:
- **Required**: All schemas must have an `input` block declaring expected fields
- **Type Declarations**: Each field can specify type: `key :field, type: :string`
- **Complex Types**: Use helper functions: `array(:element_type)` and `hash(:key_type, :value_type)`
- **Domain Constraints**: Fields can have domains: `key :age, type: :integer, domain: 18..65` (declared but not yet validated)
- **Field Access**: Use `input.field_name` to reference input fields in expressions
- **Separation**: Input metadata (types, domains) is separate from business logic

**Expression Types**:
- `input.field_name` - Access input data (replaces deprecated `key(:field)`)
- `ref(:name)` - Reference other declarations
- `fn(:name, args...)` - Function calls
- `[element1, element2]` - Lists
- Literals (numbers, strings, booleans)

**Analysis Flow**:
1. Parse DSL → Syntax Tree
2. Analyze Syntax Tree → Analysis Result (dependency graph, type information, topo order)
3. Compile → Executable Schema  
4. Execute with Runner

**Type System** (`lib/kumi/types.rb`):
- Simple symbol-based type system for clean and intuitive declaration
- **Dual Type System**: Declared types (from input blocks) and inferred types (from expressions)
- Automatic type inference for all declarations based on expression analysis
- Type primitives: `:string`, `:integer`, `:float`, `:boolean`, `:any`, `:symbol`, `:regexp`, `:time`, `:date`, `:datetime`
- Collection types: `array(:element_type)` and `hash(:key_type, :value_type)` helper functions
- Type compatibility checking and unification algorithms for numeric types
- Enhanced error messages showing type provenance (declared vs inferred)
- Legacy compatibility constants maintained for backward compatibility

### Examples Directory

The `examples/` directory contains comprehensive examples showing Kumi usage patterns:
- `input_block_typing_showcase.rb` - Demonstrates input block typing features (current best practices)

*Note: Some examples may use deprecated syntax and should be updated to use the new input block system.*

## Test Structure

- `spec/kumi/` - Unit tests for core components
- `spec/integration/` - Integration tests for full workflows
- `spec/fixtures/` - Test fixtures and sample schemas
- `spec/support/` - Test helpers (`ast_factory.rb`, `schema_generator.rb`)

## Key Files for Understanding

1. `lib/kumi/schema.rb` - Start here to understand the main API
2. `examples/input_block_typing_showcase.rb` - Comprehensive example of current features
3. `lib/kumi/analyzer.rb` - Core analysis pipeline with multi-pass system
4. `lib/kumi/types.rb` - Static type system implementation
5. `lib/kumi/function_registry.rb` - Available functions and extension patterns
6. `lib/kumi/analyzer/passes/type_inferencer.rb` - Type inference algorithm
7. `lib/kumi/analyzer/passes/type_checker.rb` - Type validation with enhanced error messages
8. `spec/kumi/input_block_spec.rb` - Input block syntax and behavior
9. `spec/integration/compiler_integration_spec.rb` - End-to-end test examples

## Input Block System Details

### Required Input Blocks
- **All schemas must have an input block** - This is now mandatory
- Input blocks declare expected fields with optional type and domain constraints
- Fields are accessed via `input.field_name` syntax (replaces deprecated `key(:field)`)

### Type System Integration
- **Declared Types**: Explicit type declarations in input blocks (`key :field, type: :string`)
- **Inferred Types**: Types automatically inferred from expression analysis
- **Type Checking**: Validates compatibility between declared and inferred types
- **Enhanced Errors**: Error messages show type provenance (declared vs inferred)
- **Helper Functions**: Use `array(:type)` and `hash(:key_type, :value_type)` for complex types

### Parser Components
- `input_dsl_proxy.rb` - Restricts input block to only allow `key` declarations
- `input_proxy.rb` - Handles `input.field_name` references in expressions
- `input_collector.rb` - Collects and validates field metadata consistency

### Domain Constraints
- Can be declared: `key :age, type: :integer, domain: 18..65`
- **Not yet implemented**: Domain validation logic is planned but not active
- Field metadata includes domain information for future validation

### Type Examples
```ruby
input do
  # Primitive types
  key :name, type: :string
  key :age, type: :integer
  key :score, type: :float
  key :active, type: :boolean
  
  # Complex types using helper functions
  key :tags, type: array(:string)
  key :scores, type: array(:float)
  key :metadata, type: hash(:string, :any)
  key :nested_data, type: hash(:string, array(:integer))
end
```

## Common Development Tasks

### Adding New Analyzer Passes
1. Create pass class inheriting from `PassBase` in `lib/kumi/analyzer/passes/`
2. Implement `run(errors)` method that calls `set_state(key, value)` to store results
3. Add pass to `PASSES` array in `lib/kumi/analyzer.rb` in correct order
4. Consider dependencies on other passes (e.g., TypeChecker needs TypeInferencer)

### Working with AST Nodes
- All nodes include `Node` module for location tracking
- Use `spec/support/ast_factory.rb` helpers in tests
- Field declarations use `FieldDecl` nodes with name, domain, and type
- Field references use `FieldRef` nodes (from `input.field_name`)

### Testing Input Block Features
- See `spec/kumi/input_block_spec.rb` for comprehensive input block tests
- Use `schema_generator.rb` helper for creating test schemas
- All integration tests now require input blocks

## Architecture Design Principles

- **Multi-pass Analysis**: Each analysis pass has a single responsibility and builds on previous passes
- **Immutable Syntax Tree**: AST nodes are immutable; analysis results stored separately in analyzer state
- **Dependency-driven Evaluation**: All computation follows dependency graph to ensure correct order
- **Type Safety**: Optional but comprehensive type checking without breaking existing schemas
- **Backward Compatibility**: New features maintain compatibility with existing DSL and APIs
- **Ruby Integration**: Leverages Ruby's metaprogramming while providing structured analysis
- **Separation of Concerns**: Input metadata (types, domains) separated from business logic