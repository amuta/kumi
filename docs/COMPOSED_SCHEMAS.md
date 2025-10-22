# Composed Schemas

Multiple schemas can be imported and called within a single schema.

## Example: Order Processing with Price and Tax

### Step 1: Define Base Schemas

**Price Calculation** (`golden/_shared/price.rb`):
```ruby
module GoldenSchemas
  module Price
    extend Kumi::Schema

    schema do
      input do
        decimal :base_price
        decimal :discount_rate
      end

      value :discounted, input.base_price * (1.0 - input.discount_rate)
      value :discount_amount, input.base_price * input.discount_rate
    end
  end
end
```

**Tax Calculation** (`golden/_shared/tax.rb`):
```ruby
module GoldenSchemas
  module Tax
    extend Kumi::Schema

    schema do
      input do
        decimal :amount
      end

      value :tax, input.amount * 0.15
      value :total, input.amount + tax
    end
  end
end
```

### Composed Order Schema

```kumi
import :discounted, :discount_amount, from: GoldenSchemas::Price
import :total, from: GoldenSchemas::Tax

schema do
  input do
    decimal :item_price
    decimal :quantity
    decimal :discount_rate
  end

  value :subtotal, input.item_price * input.quantity
  value :price_after_discount, discounted(base_price: subtotal, discount_rate: input.discount_rate)
  value :discount_amt, discount_amount(base_price: subtotal, discount_rate: input.discount_rate)
  value :final_total, total(amount: price_after_discount)
end
```

### Test Data and Output

Input:
```json
{
  "item_price": 100.0,
  "quantity": 3,
  "discount_rate": 0.1
}
```

Output:
```json
{
  "subtotal": 300.0,
  "price_after_discount": 270.0,
  "discount_amt": 30.0,
  "final_total": 310.5
}
```

## Parameter Mapping

Imported functions are called with keyword arguments that map to the imported schema's input fields.

Price schema input fields: `base_price`, `discount_rate`
```kumi
discounted(base_price: subtotal, discount_rate: input.discount_rate)
```

Tax schema input fields: `amount`
```kumi
total(amount: price_after_discount)
```

The compiler substitutes the provided values for input references in the imported schema's expressions.

## Compilation

For each imported function call:
1. Compiler locates the declaration in the imported schema
2. Extracts the expression
3. Substitutes keyword arguments for input references
4. Inlines the substituted expression into the calling schema
5. Applies optimization passes (constant folding, CSE, dead code elimination, etc.)

## Testing

Base schemas tested independently:
```bash
bin/kumi golden test schema_imports_discount_with_tax
bin/kumi golden test schema_imports_nested_with_reductions
```

Composed schemas tested:
```bash
bin/kumi golden test schema_imports_composed_order
```

Working examples in `golden/`:
- `schema_imports_with_imports` - single import
- `schema_imports_broadcasting_with_imports` - broadcast across arrays
- `schema_imports_discount_with_tax` - multiple imports
- `schema_imports_nested_with_reductions` - nested arrays
- `schema_imports_complex_order_calc` - complex multi-import
- `schema_imports_composed_order` - composed price and tax
