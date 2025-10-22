# Schema Imports Feature

## Overview

Schema imports allow you to reuse declarations (values and traits) from one schema in another schema. Instead of duplicating logic, you can import a pure function from a shared schema and use it in your own schema.

## How It Works

### Compilation Pipeline

The schema import feature works through multiple analysis passes:

1. **NameIndexer**: Identifies all imported names in the schema
2. **ImportAnalysisPass**: Loads the source schemas and extracts their analyzed state
3. **ConvertCallToImportCall** (text parser only): Converts function calls to ImportCall nodes when the function name matches an imported declaration
4. **DependencyResolver**: Creates dependency edges for ImportCall nodes
5. **NormalizeToNASTPass**: **Substitutes** ImportCall nodes with the source expression, mapping parameters

### Key Design Principle: Static Inlining

Imports are **NOT function calls at runtime**. Instead:

1. The compiler analyzes the imported schema
2. Extracts the expression for the imported declaration
3. Substitutes it into the calling schema with parameter mapping
4. Inlines the result into the generated code

This enables:
- Zero runtime overhead
- Whole-program optimization across schema boundaries
- Automatic broadcasting and expression evaluation

### Example: Tax Calculation

**Imported Schema** (`GoldenSchemas::Tax`):
```kumi
schema do
  input do
    decimal :amount
  end

  value :tax, input.amount * 0.15
  value :total, input.amount + tax
end
```

**Calling Schema**:
```kumi
import :tax, from: GoldenSchemas::Tax

schema do
  input do
    decimal :amount
  end

  value :tax_result, tax(amount: input.amount)
  value :total, input.amount + tax_result
end
```

**Generated Ruby Code**:
```ruby
def _tax_result(input = @input)
  # The tax expression is inlined directly:
  t1 = input["amount"] || input[:amount]
  t2 = 0.15
  t1 * t2
end
```

## Syntax

### Import Declaration

Text parser syntax:
```kumi
import :name1, :name2, from: Module::Path
```

Ruby DSL syntax:
```ruby
import :name1, :name2, from: SourceModule
```

### Imported Function Calls

**Text parser** (identifier syntax):
```kumi
result = tax(amount: input.price)
```

**Ruby DSL** (function call syntax):
```ruby
result = fn(:tax, amount: input.price)
```

Both create an `ImportCall` node which gets substituted during normalization.

## Broadcasting with Imports

Imports work seamlessly with broadcasting. When you pass an array to an imported function, it broadcasts across the array:

```kumi
import :tax, from: GoldenSchemas::Tax

schema do
  input do
    array :items do
      hash :item do
        decimal :amount
      end
    end
  end

  value :item_taxes, tax(amount: input.items.item.amount)
  value :total_tax, fn(:sum, item_taxes)
end
```

With input `items: [{amount: 100}, {amount: 200}, {amount: 300}]`:
- `item_taxes` broadcasts to `[15, 30, 45]` (each computed with tax = amount * 0.15)
- `total_tax` sums to `90`

The generated code handles the broadcasting automatically through loop fusion and vectorization.

## Parameter Substitution

When you call an imported function with keyword arguments, the compiler:

1. Maps each argument name to the corresponding input field in the imported schema
2. Substitutes input references with the actual expressions provided
3. Inlines the substituted expression into the calling schema

Example:
```kumi
# Imported: value :tax, input.amount * 0.15
# Call: tax(amount: input.price)
# Substitution: input.price * 0.15
```

Multiple parameters work similarly:
```kumi
# Imported: value :discount, input.price * input.rate
# Call: discount(price: invoice.total, rate: 0.1)
# Substitution: invoice.total * 0.1
```

## Current Test Cases

### 1. `schema_imports_with_imports`
- **Purpose**: Basic import with single parameter substitution
- **Tests**: Simple function import and evaluation
- **Input**: `{amount: 100}`
- **Expected**: `{tax_result: 15, total: 115}`

### 2. `schema_imports_broadcasting_with_imports`
- **Purpose**: Broadcasting across arrays with imports
- **Tests**: Array broadcasting, loop fusion, aggregation
- **Input**: `{items: [{amount: 100}, {amount: 200}, {amount: 300}]}`
- **Expected**: `{item_taxes: [15, 30, 45], total_tax: 90}`

## Implementation Details

### Parser Level (kumi-parser gem)

**Text Parser Changes**:
- Added `import` and `from` keywords to tokenizer
- Extended `parse_imports()` to handle `import :name, from: Constant::Path` syntax
- Added `parse_imported_function_call()` to handle identifier syntax like `tax(amount: value)`
- Tracks `@imported_names` during parsing to create ImportCall nodes when appropriate

**Key Methods**:
- `parse_imports()`: Parses import declarations
- `parse_constant()`: Parses scope-resolved constants like `GoldenSchemas::Tax`
- `parse_imported_function_call()`: Parses direct function calls with keyword arguments

### Analyzer Level (kumi gem)

**New/Modified Passes**:
- `ImportAnalysisPass`: Loads source schemas, extracts analyzed state
- `SemanticConstraintValidator`: Skips validation for imported function names
- `NormalizeToNASTPass`: Performs substitution of ImportCall nodes

**Key Data Structures**:
- `ImportDeclaration`: Stores import metadata (names, source module)
- `ImportCall`: Represents a call to an imported function (fn_name, input_mapping)
- `imported_declarations`: State containing all imported names
- `imported_schemas`: State containing full analysis of imported schemas

## Architecture: Function Calls, Not Inlining

Unlike some other systems, Kumi schema imports work by **calling compiled schema functions**, not by inlining AST.

**How it works:**
1. Each imported schema is compiled to a module with methods for each declaration
2. When you import a declaration, you're importing a function
3. At runtime, the compiler generates code that:
   - Creates an instance of the imported schema module
   - Passes the mapped parameters as inputs
   - Calls the appropriate method on that instance
   - Returns the result

**Benefits:**
- No AST pollution - the importing schema doesn't need to understand the source schema's internals
- Declarations can have internal dependencies - the compiled function handles them
- Clean separation of concerns
- The compiled schema is a black box

## Testing Strategy

To verify imports are working correctly, test:

1. **Parser correctness**: ImportCall nodes are created for imported functions
2. **Substitution**: Expressions are properly substituted with parameter mapping
3. **Broadcasting**: Broadcasting works correctly with substituted expressions
4. **Optimization**: Inlined code is optimized (CSE, dead code elimination)
5. **Runtime evaluation**: Generated code produces correct results

## Future Enhancements

1. **Trait imports**: Support importing traits for reusable conditions
2. **Nested imports**: Allow imported schemas to import other schemas
3. **Import aliasing**: Rename imports on import (`import :tax as :tax_calc`)
4. **Selective exports**: Mark declarations as publicly exportable
5. **Cross-schema optimization**: Detect and optimize repeated patterns across imports
