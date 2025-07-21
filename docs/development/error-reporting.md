# Error Reporting Standards

This guide provides comprehensive standards for error reporting in Kumi, ensuring consistent, localized error messages throughout the system.

## Overview

Kumi uses a unified error reporting interface that:
- Provides consistent location information (file:line:column)
- Categorizes errors by type (syntax, semantic, type, runtime)
- Supports both immediate raising and error accumulation patterns
- Maintains backward compatibility with existing tests
- Enables enhanced error messages with suggestions and context

## Core Interface Components

### ErrorReporter Module
Central error reporting functionality with standardized error entries:

```ruby
# Create structured error entry
entry = ErrorReporter.create_error(
  "Error message",
  location: node.loc,
  type: :semantic,
  context: { additional: "info" }
)

# Add error to accumulator
ErrorReporter.add_error(errors, "message", location: node.loc)

# Immediately raise error
ErrorReporter.raise_error("message", location: node.loc, error_class: Errors::SyntaxError)
```

### ErrorReporting Mixin
Convenient methods for classes that need error reporting:

```ruby
class MyClass
  include ErrorReporting
  
  def process
    # Accumulated errors (analyzer pattern)
    report_error(errors, "message", location: node.loc, type: :semantic)
    
    # Immediate errors (parser pattern)
    raise_localized_error("message", location: node.loc, error_class: Errors::SyntaxError)
  end
end
```

## Implementation Patterns

### Parser Classes (Immediate Errors)
Parser classes should raise errors immediately when encountered:

```ruby
class DslBuilderContext
  include ErrorReporting
  
  def validate_name(name, type, location)
    return if name.is_a?(Symbol)
    
    raise_syntax_error(
      "The name for '#{type}' must be a Symbol, got #{name.class}",
      location: location
    )
  end
  
  def raise_error(message, location)
    # Legacy method - delegates to new interface
    raise_syntax_error(message, location: location)
  end
end
```

### Analyzer Passes (Accumulated Errors)
Analyzer passes should accumulate errors and report them at the end:

```ruby
class MyAnalyzerPass < PassBase
  def run(errors)
    each_decl do |decl|
      validate_declaration(decl, errors)
    end
  end
  
  private
  
  def validate_declaration(decl, errors)
    # New error reporting method
    report_error(
      errors, 
      "Validation failed for #{decl.name}",
      location: decl.loc,
      type: :semantic
    )
    
    # Legacy method (backward compatible)
    add_error(errors, decl.loc, "Legacy format message")
  end
end
```

## Location Resolution Best Practices

### Always Provide Location When Available
```ruby
# Good: Specific node location
report_error(errors, "Type mismatch", location: node.loc)

# Acceptable: Fallback location
report_error(errors, "Cycle detected", location: first_node&.loc || :cycle)

# Avoid: No location information
report_error(errors, "Error occurred", location: nil)
```

### Complex Error Location Resolution
For errors that span multiple nodes or are contextual:

```ruby
def report_cycle(cycle_path, errors)
  # Find first declaration in cycle for location context
  first_decl = find_declaration_by_name(cycle_path.first)
  location = first_decl&.loc || :cycle
  
  report_error(
    errors,
    "cycle detected: #{cycle_path.join(' → ')}",
    location: location,
    type: :semantic
  )
end

def find_declaration_by_name(name)
  return nil unless schema
  
  schema.attributes.find { |attr| attr.name == name } ||
    schema.traits.find { |trait| trait.name == name }
end
```

### Location Fallbacks
When AST location is not available, use meaningful symbolic locations:

```ruby
# Cycle detection
location = node.loc || :cycle

# Type inference failures  
location = decl.loc || :type_inference

# Cross-reference resolution
location = ref_node.loc || :reference_resolution
```

## Error Categorization

### Error Types
- `:syntax` - Parse-time structural errors
- `:semantic` - Analysis-time logical errors  
- `:type` - Type system violations
- `:runtime` - Execution-time failures

### Type-specific Methods
```ruby
# Syntax errors (parser)
report_syntax_error(errors, "Invalid syntax", location: loc)
raise_syntax_error("Invalid syntax", location: loc)

# Semantic errors (analyzer)  
report_semantic_error(errors, "Logic error", location: loc)

# Type errors (type checker)
report_type_error(errors, "Type mismatch", location: loc)
```

## Enhanced Error Messages

### Basic Enhanced Errors
```ruby
report_enhanced_error(
  errors,
  "undefined reference to `missing_field`",
  location: node.loc,
  similar_names: ["missing_value", "missing_data"],
  suggestions: [
    "Check spelling of field name",
    "Ensure field is declared in input block"
  ]
)
```

### Context-rich Errors
```ruby
report_error(
  errors,
  "Type mismatch in function call",
  location: call_node.loc,
  type: :type,
  context: {
    function: call_node.fn_name,
    expected_type: expected,
    actual_type: actual,
    argument_position: position
  }
)
```

## Backward Compatibility

### Legacy Format Support
The system supports both legacy `[location, message]` arrays and new `ErrorEntry` objects:

```ruby
# Analyzer.format_errors handles both formats
def format_errors(errors)
  errors.map do |error|
    case error
    when ErrorReporter::ErrorEntry
      error.to_s  # New format: "at file.rb:10:5: message"
    when Array
      loc, msg = error
      "at #{loc || '?'}: #{msg}"  # Legacy format
    end
  end.join("\n")
end
```

### Migration Strategy
1. **New code**: Use new error reporting methods (`report_error`, `raise_localized_error`)
2. **Existing code**: No changes required - `add_error` method maintained for compatibility
3. **Enhanced features**: Migrate to new methods to access suggestions, context, and categorization

## Testing Error Reporting

### Error Location Testing
```ruby
RSpec.describe "Error Location Verification" do
  it "reports errors at correct locations" do
    schema_code = <<~RUBY
      Kumi.schema do
        input { integer :age }
        trait :adult, (input.age >= 18)
        trait :adult, (input.age >= 21)  # Line 4: Duplicate
      end
    RUBY

    begin
      eval(schema_code, binding, "test.rb", 1)
    rescue Kumi::Errors::SemanticError => e
      expect(e.message).to include("test.rb:4")
      expect(e.message).to include("duplicated definition")
    end
  end
end
```

### Error Quality Testing
```ruby
it "provides comprehensive error information" do
  error = expect_semantic_error do
    schema do
      input { string :name }
      value :result, fn(:add, input.name, 5)
    end
  end
  
  expect(error.message).to include("add")           # Function name
  expect(error.message).to include("string")        # Actual type
  expect(error.message).to include("expects")       # Clear expectation
  expect(error.message).to match(/:\d+:/)          # Line number
end
```

### Edge Case Testing
Use `spec/integration/potential_breakage_spec.rb` patterns:

```ruby
it "detects edge case that should break" do
  expect do
    schema do
      input { integer :x }
      # Edge case that might not be caught
      value :result, some_edge_case_construct
    end
  end.to raise_error(Kumi::Errors::SemanticError)
end
```

## Performance Considerations

### Error Object Creation
- ErrorEntry objects are lightweight structs
- Location formatting is lazy (only when `to_s` is called)
- Context information is stored efficiently in hashes

### Batch Error Processing
For analyzer passes processing many nodes:

```ruby
def run(errors)
  # Batch process nodes to minimize error object creation
  invalid_nodes = collect_invalid_nodes
  
  invalid_nodes.each do |node|
    report_error(errors, "Invalid: #{node.name}", location: node.loc)
  end
end
```

## Common Patterns and Anti-patterns

### ✅ Good Patterns
```ruby
# Clear, specific error messages
report_error(errors, "argument 1 of `fn(:add)` expects float, got string", location: arg.loc)

# Proper location resolution
location = node.loc || fallback_location_for_context

# Type-appropriate error categorization
report_type_error(errors, "type mismatch", location: node.loc)
```

### ❌ Anti-patterns
```ruby
# Vague error messages
report_error(errors, "error", location: node.loc)

# Missing location information
report_error(errors, "something failed", location: nil)

# Wrong error categorization
report_syntax_error(errors, "type mismatch", location: node.loc)  # Should be type error
```

## Error Message Guidelines

### Message Format
- Start with lowercase (automatic capitalization in display)
- Be specific about what failed and why
- Include relevant context (function names, types, values)
- Avoid technical jargon in user-facing messages

### Examples
```ruby
# Good messages
"argument 1 of `fn(:add)` expects float, got input field `name` of declared type string"
"duplicated definition `adult`"
"undefined reference to `missing_field`"
"cycle detected: a → b → a"

# Messages to improve  
"validation failed"
"error in processing" 
"something went wrong"
```

This error reporting system ensures that users get clear, actionable feedback about issues in their Kumi schemas, with precise location information to help them fix problems quickly.