# Development Guides

This directory contains detailed guides for developing and maintaining Kumi. These guides complement the high-level information in the main `CLAUDE.md` file.

## Guide Index

### Architecture & Design
- [Error Reporting Standards](error-reporting.md) - Comprehensive guide to unified error reporting
- [Analyzer Pass Development](analyzer-passes.md) - How to create new analyzer passes
- [Type System Integration](type-system.md) - Working with Kumi's type inference and checking

### Code Quality & Standards  
- [Testing Standards](testing-standards.md) - Testing patterns and requirements
- [Code Organization](code-organization.md) - File structure and class design patterns
- [RuboCop Guidelines](rubocop-guidelines.md) - Code style and quality requirements

### Common Tasks
- [Adding New Functions](adding-functions.md) - Extending the FunctionRegistry
- [DSL Extension Patterns](dsl-extensions.md) - Adding new DSL constructs
- [Performance Considerations](performance.md) - Guidelines for maintaining performance

### Integration & Compatibility
- [Backward Compatibility](backward-compatibility.md) - Maintaining compatibility during changes
- [Migration Patterns](migration-patterns.md) - Safe patterns for evolving APIs
- [Zeitwerk Integration](zeitwerk.md) - Autoloading patterns and requirements

## Quick Reference

### Key Principles
1. **Unified Error Reporting**: All errors must provide clear location information
2. **Multi-pass Analysis**: Each analyzer pass has single responsibility  
3. **Backward Compatibility**: Changes maintain existing API compatibility
4. **Type Safety**: Optional but comprehensive type checking
5. **Ruby Integration**: Leverage Ruby idioms while maintaining structure

### Common Commands
```bash
# Run all tests
bundle exec rspec

# Run specific test categories
bundle exec rspec spec/integration/
bundle exec rspec spec/kumi/analyzer/

# Check code quality
bundle exec rubocop
bundle exec rubocop -a

# Validate error reporting
bundle exec ruby test_location_improvements.rb
```

### File Templates

**New Analyzer Pass**:
```ruby
# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      class MyNewPass < PassBase
        def run(errors)
          # Implementation with proper error reporting
          report_error(errors, "message", location: node.loc, type: :semantic)
        end
      end
    end
  end
end
```

**New Integration Test**:
```ruby
# frozen_string_literal: true

RSpec.describe "My Feature Integration" do
  it "validates the feature works correctly" do
    schema = build_schema do
      input { integer :field }
      value :result, input.field * 2
    end
    
    expect(schema.from(field: 5).fetch(:result)).to eq(10)
  end
end
```

## Contributing Guidelines

### Before Making Changes
1. Check relevant development guide in this directory
2. Review `CLAUDE.md` for high-level architecture understanding
3. Run existing tests to ensure baseline functionality
4. Consider backward compatibility implications

### After Making Changes  
1. Update relevant development guides if patterns change
2. Add or update tests for new functionality
3. Run full test suite: `bundle exec rspec`
4. Check code quality: `bundle exec rubocop`
5. Verify error reporting quality with integration tests

### Adding New Guides
When adding new development guides:
1. Create focused, actionable guides for specific development tasks
2. Include code examples and common patterns
3. Reference related files and tests
4. Update this README index
5. Cross-reference from main `CLAUDE.md` if needed

## Guide Maintenance

These guides should be kept up-to-date as the codebase evolves:
- **Review quarterly** for accuracy and completeness
- **Update immediately** when patterns or APIs change significantly  
- **Expand based on common questions** during development
- **Consolidate** overlapping or redundant information

The goal is to make Kumi development efficient and consistent while maintaining high code quality.