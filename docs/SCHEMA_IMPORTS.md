# Schema Imports Feature

## Overview

Schema imports allow you to reuse declarations (values and traits) from one schema in another schema by importing them from a source module.

## How It Works

### Compilation Pipeline

The schema import feature works through multiple analysis passes:

1. **NameIndexer**: Identifies all imported names in the schema
2. **ImportAnalysisPass**: Loads the source schemas and extracts their analyzed state
3. **ConvertCallToImportCall** (text parser only): Converts function calls to ImportCall nodes when the function name matches an imported declaration
4. **DependencyResolver**: Creates dependency edges for ImportCall nodes
5. **NormalizeToNASTPass**: **Substitutes** ImportCall nodes with the source expression, mapping parameters

### Key Design Principle: Runtime Function Calls

Imports are **compiled as runtime function calls** to the imported schema:

1. The compiler analyzes the imported schema and generates its module methods
2. When an imported function is called, the generated code invokes `ImportedModule._function_name(input_hash)`
3. This allows for modular code generation and schema reuse

**Behavior:**
- Imported functions are called at runtime via generated code
- Broadcasting still applies - the calling function iterates and calls the imported function for each array element
- Parameter mapping creates input hashes that are passed to the imported function

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
  # The imported function is called at runtime:
  t1 = input["amount"] || input[:amount]
  t2 = GoldenSchemas::Tax._tax({"amount" => t1})
  t2
end
```

Note: The generated code uses module-level functions (`def self._name(input)`) rather than instance methods. Imported functions are invoked as module methods with parameter mapping, enabling schema composition and reuse.

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

When you pass an array to an imported function, the calling schema iterates over the array and calls the imported function for each element:

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
- The generated code loops over each item and calls `GoldenSchemas::Tax._tax({"amount" => item.amount})`
- `item_taxes` becomes `[15, 30, 45]`
- `total_tax` sums to `90`

The generated code performs loop iteration and calls the imported function for each array element.

## Parameter Mapping

When you call an imported function with keyword arguments, the compiler:

1. Maps each keyword argument name to the corresponding input field in the imported schema
2. Constructs an input hash with the mapped parameter values
3. Generates a runtime call to the imported function with this hash

Example:
```kumi
# Imported schema input field: amount
# Call: fn(:tax, amount: input.price)
# Generated: GoldenSchemas::Tax._tax({"amount" => input.price})
```

Multiple parameters work similarly:
```kumi
# Imported schema input fields: price, rate
# Call: fn(:discount, price: invoice.total, rate: 0.1)
# Generated: GoldenSchemas::Discount._discount({"price" => invoice.total, "rate" => 0.1})
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

6. **`schema_imports_complex_order_calc`** - Multiple imports with nested arrays
   - Imports tax, discount, and subtotal functions
   - Tests order processing with taxes, discounts, and summaries across multiple orders

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
- `ImportAnalysisPass`: Loads source schemas, extracts analyzed state, and prepares for runtime calls
- `SemanticConstraintValidator`: Skips validation for imported function names
- `CodegenPass`: Generates runtime function calls to imported schema methods

**Key Data Structures**:
- `ImportDeclaration`: Stores import metadata (names, source module)
- `ImportCall`: Represents a call to an imported function (fn_name, input_mapping)
- `imported_declarations`: State containing all imported names
- `imported_schemas`: State containing full analysis of imported schemas (used to ensure schemas are compiled before use)

## How Imports Are Compiled

**Imports are compiled as runtime function calls:**

1. The imported schema is fully analyzed and compiled as a standalone module with its own methods
2. When you call an imported function, the compiler generates a call to that module's method
3. Parameters are mapped and passed as a hash to the imported function at runtime

**Example:**

Imported schema defines: `value :tax, input.amount * 0.15`

Your schema calls: `fn(:tax, amount: input.price)`

Compiler produces:
```ruby
t1 = input["price"] || input[:price]
t2 = GoldenSchemas::Tax._tax({"amount" => t1})
```

The imported function executes independently and returns its result to the calling schema.

## Testing Strategy

To verify imports are working correctly, test:

1. **Parser correctness**: ImportCall nodes are created for imported functions
2. **Parameter mapping**: Input hashes are correctly constructed from keyword arguments
3. **Runtime calls**: Generated code properly invokes imported schema methods with parameter hashes
4. **Broadcasting**: Loop iteration works correctly when passing arrays to imported functions
5. **Runtime evaluation**: Generated code produces correct results by calling imported functions

## Future Enhancements

1. **Trait imports**: Support importing traits for reusable conditions
2. **Nested imports**: Allow imported schemas to import other schemas
3. **Import aliasing**: Rename imports on import (`import :tax as :tax_calc`)
4. **Selective exports**: Mark declarations as publicly exportable
5. **Cross-schema optimization**: Detect and optimize repeated patterns across imports
