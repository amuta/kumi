# Schema Imports

Schema imports let one schema reuse declarations from another. The imported
logic is **inlined at compile time** — the generated code is self-contained
and has no runtime dependency on the source module.

## Syntax

Declare imports before the schema body, then call them like functions with
keyword arguments naming the source schema's input fields:

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

Ruby DSL form:

```ruby
import :tax, from: GoldenSchemas::Tax

schema do
  input { decimal :amount }
  value :tax_result, fn(:tax, amount: input.amount)
end
```

Multiple names can be imported from one module
(`import :tax, :discounted, from: ...`), and a schema can import from several
modules.

## Defining a Reusable Schema

Any Kumi schema module can be imported:

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

```kumi
import :subtotal, from: GoldenSchemas::Subtotal

schema do
  input do
    array :order_items do
      hash :item do
        integer :quantity
        integer :unit_price
      end
    end
  end

  value :order_total, subtotal(items: input.order_items)
end
```

The caller's input names don't have to match the source schema's — the
`items:` keyword maps the caller's `order_items` onto the source's `items`
parameter, and the compiler renames the source schema's axes to the caller's
at the inlining boundary.

## Broadcasting

Imports participate in axis broadcasting like any other expression. Passing a
vectorized argument applies the imported logic per element:

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

  value :item_taxes, tax(amount: input.items.item.amount)  # per item
  value :total_tax, fn(:sum, item_taxes)                   # scalar
end
```

With `items: [{amount: 100}, {amount: 200}, {amount: 300}]`, `item_taxes` is
`[15, 30, 45]` and `total_tax` is `90`. Imports containing reductions also
compose: passing a nested array applies the reduction per outer element (see
`golden/schema_imports_nested_with_reductions`).

## How It Compiles

1. **Parse** — `import` declarations are recorded; calls to imported names
   become `ImportCall` nodes with their keyword-argument mapping.
2. **Analysis** — `ImportAnalysisPass` loads and analyzes the source schemas;
   `ImportCall` nodes flow through NAST/SNAST with dimensional stamps.
3. **DFIR inlining** — the `ImportInlining` pass splices the callee's
   dataflow body into the caller, substituting arguments for the callee's
   input loads. Axis names and plan references are canonicalized to the
   caller's input plans at this boundary, so later layers never see
   callee-named axes.
4. **Codegen** — the result is ordinary fully-inlined DFIR; generated Ruby/JS
   contains the imported computation directly, with no call to the source
   module.

For the imported `value :tax, input.amount * 0.15`, the caller's generated
code is simply:

```ruby
def self._tax_result(input)
  t1 = input["amount"] || input[:amount]
  t2 = 0.15
  t3 = t1 * t2
  return t3
end
```

## Worked Examples

The `golden/schema_imports_*` suites are the executable reference:

| Golden test | Covers |
|---|---|
| `schema_imports_with_imports` | single import, scalar parameters |
| `schema_imports_multiple` | multiple imports in one schema |
| `schema_imports_broadcasting_with_imports` | broadcasting an import over an array |
| `schema_imports_line_items` | imported reduction, renamed input |
| `schema_imports_nested_with_reductions` | imports over nested arrays |
| `schema_imports_composed_order` / `schema_imports_complex_order_calc` | composing several imports into an order-processing pipeline |

Shared source schemas live in `golden/_shared/` and are loaded automatically
when running golden tests.
