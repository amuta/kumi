# Array Broadcasting

Automatic vectorization of operations over array fields with element-wise computation and aggregation.

## Overview

The array broadcasting system enables natural field access syntax on array inputs (`input.items.price`) that automatically applies operations element-wise across the array, with intelligent detection of map vs reduce operations.

## Core Mechanism

The system uses a three-stage pipeline:

1. **Parser** - Creates InputElementReference AST nodes for nested field access
2. **BroadcastDetector** - Identifies which operations should be vectorized vs scalar
3. **Compiler** - Generates appropriate map/reduce functions based on usage context

## Basic Broadcasting

```ruby
schema do
  input do
    array :line_items do
      float   :price
      integer :quantity
      string  :category
    end
    float :tax_rate, type: :float
  end

  # Element-wise computation - broadcasts over each item
  value :subtotals, input.line_items.price * input.line_items.quantity
  
  # Element-wise traits - applied to each item
  trait :is_taxable, (input.line_items.category != "digital")
  
  # Conditional logic - element-wise evaluation
  value :taxes, fn(:if, is_taxable, subtotals * input.tax_rate, 0.0)
end
```

## Aggregation Operations

Operations that consume arrays to produce scalars are automatically detected:

```ruby
schema do
  # These aggregate the vectorized results
  value :total_subtotal, fn(:sum, subtotals)
  value :total_tax, fn(:sum, taxes)
  value :grand_total, total_subtotal + total_tax
  
  # Statistics over arrays
  value :avg_price, fn(:avg, input.line_items.price)
  value :max_quantity, fn(:max, input.line_items.quantity)
end
```

## Field Access Nesting

Supports arbitrary depth field access with path building:

```ruby
schema do
  input do
    array :orders do
      array :items do
        hash :product do
          string :name
          float  :base_price
        end
        integer :quantity
      end
    end
  end

  # Deep field access - automatically broadcasts over nested arrays  
  value :all_product_names, input.orders.items.product.name
  value :total_values, input.orders.items.product.base_price * input.orders.items.quantity
end
```

## Type Inference

The type system automatically infers appropriate types for broadcasted operations:

- `input.items.price` (float array) → inferred as `:float` per element
- `input.items.price * input.items.quantity` → element-wise `:float` result
- `fn(:sum, input.items.price)` → scalar `:float` result

## Implementation Details

### Parser Layer
- **InputFieldProxy** - Handles `input.field.subfield...` with path building
- **InputElementReference** - AST node representing array field access paths

### Analysis Layer  
- **BroadcastDetector** - Identifies vectorized vs scalar operations
- **TypeInferencer** - Infers types for array element access patterns

### Compilation Layer
- **Automatic Dispatch** - Maps element-wise operations to array map functions
- **Reduction Detection** - Converts aggregation functions to array reduce operations

## Usage Patterns

### Element-wise Operations
```ruby
# All of these broadcast element-wise
value :discounted_prices, input.items.price * 0.9
trait :expensive, (input.items.price > 100.0)  
value :categories, input.items.category
```

### Aggregation Operations
```ruby
# These consume arrays to produce scalars
value :item_count, fn(:size, input.items)
value :total_price, fn(:sum, input.items.price)
value :has_expensive, fn(:any?, expensive)
```

### Mixed Operations
```ruby
# Element-wise computation followed by aggregation
value :line_totals, input.items.price * input.items.quantity
value :order_total, fn(:sum, line_totals)
value :avg_line_total, fn(:avg, line_totals)
```

### Conditional Aggregation Functions

Kumi provides powerful conditional aggregation functions that make working with vectorized traits clean and intuitive:

```ruby
# Step 1: Create vectorized values and traits
value :revenues, input.sales.price * input.sales.quantity  # → [3000.0, 2000.0, 1250.0]
trait :expensive, input.sales.price > 100                   # → [true, true, false]
trait :bulk_order, input.sales.quantity >= 15              # → [false, false, true]

# Step 2: Use conditional aggregation functions (NEW - clean and readable)
value :expensive_count, fn(:count_if, expensive)                    # → 2
value :expensive_total, fn(:sum_if, revenues, expensive)            # → 5000.0
value :expensive_average, fn(:avg_if, revenues, expensive)          # → 2500.0

# Step 3: Combine conditions for complex filtering
trait :expensive_bulk, expensive & bulk_order                       # → [false, false, false]
value :expensive_bulk_total, fn(:sum_if, revenues, expensive_bulk)  # → 0.0
```

**Old cascade pattern** (verbose, harder to read):
```ruby
# OLD WAY - required verbose cascade patterns
value :expensive_amounts do
  on expensive, revenues
  base 0.0
end
value :expensive_total, fn(:sum, expensive_amounts)

value :expensive_count_markers do
  on expensive, 1.0
  base 0.0
end
value :expensive_count, fn(:sum, expensive_count_markers)
```

**New conditional functions** (clean, direct):
```ruby
# NEW WAY - direct and readable
value :expensive_total, fn(:sum_if, revenues, expensive)
value :expensive_count, fn(:count_if, expensive)
value :expensive_average, fn(:avg_if, revenues, expensive)
```

The conditional aggregation functions are now the idiomatic way to work with boolean arrays in Kumi.

## Common Patterns and Gotchas

### Operator Precedence with Mixed Arithmetic

**Problem**: Complex arithmetic expressions with arrays can fail due to precedence parsing:

```ruby
# This fails with confusing error message
value :ones, input.items.price * 0 + 1
# Error: "no implicit conversion of Integer into Array"

# The expression is parsed as: (input.items.price * 0) + 1
# Which becomes: [0.0, 0.0, 0.0] + 1 (array + scalar in wrong context)
```

**Solutions**:

```ruby
# Use explicit function calls
value :ones, fn(:add, input.items.price * 0, 1)

# Use cascade pattern (most idiomatic)
trait :always_true, input.items.price >= 0
value :ones do
  on always_true, 1.0
  base 0.0
end

# Use separate steps
value :zeros, input.items.price * 0
value :ones, zeros + 1
```

The cascade pattern is preferred as it's more explicit about intent and leverages Kumi's automatic scalar broadcasting.

## Error Handling

### Dimension Mismatch Detection

Array broadcasting operations are only valid within the same array source. Attempting to broadcast across different arrays generates detailed error messages:

```ruby
schema do
  input do
    array :items do
      string :name
    end
    array :logs do  
      string :user_name
    end
  end

  # This will generate a dimension mismatch error
  trait :same_name, input.items.name == input.logs.user_name
end

# Error:
# Cannot broadcast operation across arrays from different sources: items, logs. 
# Problem: Multiple operands are arrays from different sources:
#   - Operand 1 resolves to array(string) from array 'items'
#   - Operand 2 resolves to array(string) from array 'logs'
# Direct operations on arrays from different sources is ambiguous and not supported. 
# Vectorized operations can only work on fields from the same array input.
```

The error messages provide:
- **Quick Summary**: Identifies the conflicting array sources
- **Type Information**: Shows the resolved types of each operand  
- **Clear Explanation**: Why the operation is ambiguous and not supported

## Performance Characteristics

- **Single Pass** - Each array is traversed once per computation chain
- **Lazy Evaluation** - Operations are composed into pipelines  
- **Memory Efficient** - No intermediate array allocations for simple operations
- **Type Safe** - Full compile-time type checking for array element operations