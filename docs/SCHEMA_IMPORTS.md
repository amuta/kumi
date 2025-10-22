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
def self._tax_result(input)
  # The tax expression is inlined directly:
  t1 = input["amount"] || input[:amount]
  t2 = 0.15
  t1 * t2
end
```

Note: The generated code uses module-level functions (`def self._name(input)`) rather than instance methods. This enables schema imports to be called directly on the compiled modules.

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

## Golden Test Cases

### Basic Tests
1. **`schema_imports_with_imports`** - Single import, scalar parameters
2. **`schema_imports_broadcasting_with_imports`** - Broadcasting imported functions across arrays

### Advanced Tests
3. **`schema_imports_line_items`** - Importing reduction functions
   - Imports `:subtotal` (sums quantity × price over array)
   - Tests array aggregation through imports

4. **`schema_imports_discount_with_tax`** - Multiple imports from different schemas
   - Imports `:tax`, `:discounted`, `:savings`
   - Tests composing multiple imported functions in sequence

5. **`schema_imports_nested_with_reductions`** - Nested arrays with imports
   - Imports subtotal and applies it to nested order structure
   - Tests broadcasting imports through multiple levels

6. **`schema_imports_complex_order_calc`** - Full production-like example
   - Imports tax, discount, and subtotal functions
   - Demonstrates complete order processing pipeline with taxes, discounts, and summaries across multiple orders

## Creating Reusable Schemas

Shared schemas are defined in `golden/_shared/` as Ruby DSL modules:

```ruby
module GoldenSchemas
  module Subtotal
    extend Kumi::Schema

    schema do
      input do
        array :items do
          hash :item do
            integer :quantity
            integer :unit_price
          end
        end
      end

      value :subtotal, fn(:sum, input.items.item.quantity * input.items.item.unit_price)
    end
  end
end
```

Then import in any schema:
```kumi
import :subtotal, from: GoldenSchemas::Subtotal

schema do
  value :order_total, subtotal(items: input.order_items)
end
```

The shared schemas are automatically loaded and compiled in JIT mode when running golden tests.

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

## How Imports Are Compiled

**Imports use expression substitution with direct inlining:**

1. The imported schema is fully analyzed and compiled to extract each declaration's expression
2. When you call an imported function, the compiler substitutes its expression into your schema
3. The substituted expression is then optimized and inlined into the final generated code

**Example:**

Imported schema defines: `value :tax, input.amount * 0.15`

Your schema calls: `tax(amount: input.price)`

Compiler produces: `input.price * 0.15` (inlined directly, no function call overhead)

**Benefits:**
- **Zero runtime overhead** - imported expressions are inlined, not called at runtime
- **Whole-program optimization** - the optimizer sees the inlined code and can apply CSE, constant folding, etc. across schema boundaries
- **Broadcasting works naturally** - when you pass an array, the inlined expression broadcasts automatically
- **Clean separation** - importing schema doesn't need to know about imported schema's internal implementation

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
