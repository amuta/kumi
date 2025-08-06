# Compiler Design Principles

## Core Principle: Smart Analyzer, Dumb Compiler

The Kumi compiler follows a strict separation of concerns:

### Analyzer Phase (Smart)
- **Makes all decisions** about how operations should be executed
- **Analyzes semantic context** to determine operation modes
- **Pre-computes execution strategies** and stores in metadata
- **Resolves complex logic** like nested array broadcasting, reduction flattening, etc.
- **Produces complete instructions** for the compiler to follow

### Compiler Phase (Dumb)
- **Follows metadata instructions** without making decisions
- **No conditional logic** based on data types, function types, or structure analysis
- **Mechanically executes** the pre-computed strategy from analyzer
- **Pure translation** from AST + metadata → executable functions

## Examples

### ❌ BAD: Compiler Making Decisions
```ruby
def compile_call(expr)
  if Kumi::Registry.reducer?(expr.fn_name)
    if nested_array_detected?(values)
      # Compiler deciding to flatten
      flatten_and_call(expr.fn_name, values)
    end
  end
end
```

### ✅ GOOD: Compiler Following Metadata
```ruby
def compile_call(expr)
  # Just read the pre-computed strategy
  strategy = @analysis.metadata[:call_strategies][expr]
  execute_strategy(strategy, expr)
end
```

### ❌ BAD: Runtime Structure Analysis
```ruby
def vectorized_function_call(fn_name, values)
  # Compiler analyzing structure at runtime
  if values.any? { |v| deeply_nested?(v) }
    apply_nested_broadcasting(fn, values)
  end
end
```

### ✅ GOOD: Pre-computed Broadcasting Plan
```ruby
def compile_element_field_reference(expr)
  # Analyzer already determined the strategy
  metadata = @analysis.state[:broadcasts][:nested_paths][expr.path]
  traverse_nested_path(ctx, expr.path, metadata[:operation_mode])
end
```

## Benefits

1. **Predictable Performance**: No runtime analysis or decision-making
2. **Easier Testing**: Compiler behavior determined entirely by metadata
3. **Maintainable**: Complex logic isolated in analyzer passes
4. **Extensible**: New features added by extending analyzer, not compiler
5. **Debuggable**: All decisions visible in analyzer metadata

## Implementation Pattern

For any new compiler feature:

1. **Analyzer Pass**: Analyze the requirement and store strategy in metadata
2. **Metadata Schema**: Define clear data structure for the strategy
3. **Compiler Method**: Read metadata and execute strategy mechanically
4. **No Conditionals**: Avoid `if` statements based on runtime data in compiler

## Metadata-Driven Architecture

The compiler should be a pure **metadata interpreter**:
- Input: AST + Analyzer Metadata
- Output: Executable Functions
- Process: Mechanical translation following metadata instructions

This ensures the compiler remains simple, fast, and maintainable as the system grows in complexity.

## Three-Address Code (TAC) IR Design

### Principle: Flatten Complex Expressions to Linear Operations
- **Complex nested expressions** decomposed into simple three-address operations
- **Temporary variables** generated for intermediate results  
- **Linear instruction sequence** replaces nested metadata structures
- **Consistent operand format** across all operation types

### TAC Generation Rules
- **Simple expressions**: Single instruction, no decomposition
- **Nested expressions**: Generate `__temp_N` variables for sub-expressions  
- **Declaration references**: Preserve without decomposition
- **Inline expressions**: Flatten to temp + reference chain

### Examples

#### ❌ BAD: Complex Nested Metadata
```ruby
{
  type: :computed_result,
  operation_metadata: {
    operation_type: :vectorized,
    operands: [...nested_operands...]
  }
}
```

#### ✅ GOOD: TAC Linear Instructions
```ruby
[
  { name: :__temp_1, operands: [:input_element, :literal] },
  { name: :result, operands: [:__temp_1_ref, :input_field] }
]
```

### Benefits
- **Eliminates nested_call complexity** in broadcast detector
- **Simplifies compiler logic** - all operations uniform
- **Improves debugging** - clear linear execution order  
- **Enables optimizations** - standard compiler techniques apply
- **Consistent operand handling** - no special cases

### TAC Operand Types
- `input_element_reference`: Array field access (`items.value:element`)
- `input_reference`: Simple field access (`threshold:structure`)  
- `declaration_reference`: Reference to computed value or temp
- `literal`: Constant values

### Architecture Decision: TAC IR Generator as Final Analyzer Pass
- **Replaces scattered IR generation** with centralized TAC pass
- **Analyzer produces TAC instructions** in dependency order
- **Compiler mechanically executes** TAC operations
- **No more complex operand metadata** - simple temp chain