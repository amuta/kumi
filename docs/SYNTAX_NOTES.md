# Kumi Syntax Notes and Edge Cases

This guide documents the parts of Kumi syntax that are easy to misread from
small examples. It focuses on the accepted forms in text `.kumi` schemas, the
embedded Ruby DSL, and the post-parse analyzer checks that often feel like
syntax errors when authoring a schema.

For the compact reference, see [SYNTAX.md](SYNTAX.md). For input declarations
only, see [INPUTS.md](INPUTS.md).

## If You Are Writing Your First Schema

Start from the JSON-like data you already have and write the `input` block as a
shape declaration. Kumi paths mirror that shape.

```json
{
  "discount": 0.1,
  "items": [
    { "price": 12.5, "quantity": 2 },
    { "price": 9.99, "quantity": 1 }
  ]
}
```

```kumi
schema do
  input do
    float :discount

    array :items do
      hash :item do
        float :price
        integer :quantity
      end
    end
  end

  value :line_total, input.items.item.price * input.items.item.quantity
  value :discounted, line_total * (1.0 - input.discount)
  value :total, fn(:sum, discounted)
end
```

Read that path as: root `items`, each `item`, then its `price`. The names are
not arbitrary once declared; if the input block says `array :items` with
`hash :item`, the element price path is `input.items.item.price`.

The first authoring loop should be:

1. Declare the input shape.
2. Write one elementwise `value` that reads an array element.
3. Add a reduction such as `fn(:sum, ...)` only when you want to collapse an
   array to a parent-level value.
4. Add `trait` names for conditions you plan to reuse.
5. Package output records with `{ key: value }` only after the scalar and array
   values are working.

Most confusion comes from three places:

- `array` declarations need an element name; `index:` is only the position name.
- `input.foo.bar` paths must exist in the declared shape.
- Some invalid schemas parse fine and fail later during analysis, because the
  parser checks source shape while the analyzer checks Kumi semantics.

## Front Ends and Error Boundaries

Kumi has two authoring front ends:

- Text schemas, usually `schema.kumi`, parsed by the `kumi-parser` gem.
- Embedded Ruby schemas, usually a module that `extend Kumi::Schema`.

Both front ends build the same `Kumi::Syntax::*` AST, but they do not catch the
same errors at the same phase.

**The text parser catches source-shape errors:**

```kumi
value :total input.amount
#            ^ expected `,` then an expression
```

Examples: missing `end`, missing comma after `value :name`, malformed string
literals, malformed hash pairs, unknown characters, invalid function option
literals.

**The analyzer catches schema-shape and semantic errors after parsing:**

```kumi
input do
  array :items
end
```

This parses as an array declaration with no child. `InputCollectorPass` then
raises that an array must declare exactly one element. Other post-parse errors
include undefined references, unknown input paths, type errors, unsupported
function overloads, dimensional mismatches, invalid `index(...)` names, and
invalid `cross` / `outer` / `shift` usage.

When improving or debugging errors, keep this boundary clear: not every
authoring error belongs in the front-end parser.

## Portable Subset

Use this style when you want a schema to work the same as text and Ruby:

```kumi
schema do
  input do
    integer :quantity
    decimal :unit_price
  end

  let :subtotal, input.quantity * input.unit_price
  trait :large, subtotal > 100
  value :total, select(large, subtotal * 0.9, subtotal)
end
```

Portable expression forms:

- `input.path.to.field`
- declaration references like `subtotal` and `large`
- arithmetic and comparison operators
- boolean `&` and `|`
- function calls with `fn(:name, args...)`
- function sugar for `select(...)`, `shift(...)`, `roll(...)`, `cross(...)`,
  `outer(...)`, `index(...)`, and numeric conversions
- array literals `[a, b, c]`
- hash literals `{ key: value, "string" => value }`
- cascades with `on trait_name, result` and `base result`

Prefer `fn(:not, expr)` for boolean negation. Do not use unary `!` in portable
schemas. The text parser currently treats `!` as an unexpected character, even
though the function registry documents `!` as an alias for the underlying
`not` function.

## Text vs Ruby Differences

Text `.kumi` schemas are deliberately narrower than Ruby.

| Feature | Text `.kumi` | Ruby DSL |
| --- | --- | --- |
| Imports before `schema do` | Supported | Not a normal Ruby DSL method; put imports inside `schema do` |
| Imports inside `schema do` | Supported | Supported |
| Arbitrary Ruby constants | Only known constants such as `Float::INFINITY` | Ruby can evaluate constants before Kumi sees them |
| Method calls like `scores.sum` | Not supported | Some Ruby refinements support collection-like calls, but avoid for portability |
| Cascade conditions | Parser can read expressions, but portable style is bare traits | Ruby cascade builder requires bare trait identifiers |
| Hash literal keys | Static labels, symbols, or strings | Static Ruby literal keys are safest; dynamic expression keys are not portable |
| Unary `!` | Not parsed | Do not rely on it; use `fn(:not, expr)` |
| Literal-left comparisons | Parsed normally | May need top-level refinements; prefer `input.age >= 80` over `80 <= input.age` |

Ruby evaluates ordinary Ruby before Kumi converts values. For example,
`"a" + "b"` in Ruby becomes the literal `"ab"` before Kumi sees it. In text
schemas, `"a" + "b"` is parsed as a Kumi operator expression. For string work,
prefer the string functions such as `fn(:concat, a, b)`.

## Input Shape Recipes

The key rule is that every `array` declares exactly one child. That child names
the element Kumi maps over.

### Scalars

```kumi
input do
  integer :age
  float :rate
  decimal :price
  string :name
  boolean :active
end
```

Access with `input.age`, `input.price`, and so on.

### Array of Scalars

```kumi
input do
  array :scores do
    integer :score
  end
end

value :doubled, input.scores.score * 2
value :total, fn(:sum, input.scores.score)
value :count, fn(:array_size, input.scores)
```

Input JSON:

```json
{ "scores": [10, 20, 30] }
```

Use `input.scores` for the whole array and `input.scores.score` for elementwise
values.

### Array of Hashes

```kumi
input do
  array :items do
    hash :item do
      decimal :price
      integer :quantity
      string :category
    end
  end
end

value :line_total, input.items.item.price * input.items.item.quantity
value :cart_total, fn(:sum, line_total)
```

Input JSON:

```json
{
  "items": [
    { "price": "12.50", "quantity": 2, "category": "book" },
    { "price": "9.99", "quantity": 1, "category": "tool" }
  ]
}
```

The array name and element name are both part of the path:
`input.items.item.price`.

### Array of Arrays

```kumi
input do
  array :rows do
    array :cols do
      integer :cell
    end
  end
end

value :row_sums, fn(:sum, input.rows.cols.cell)
value :grand_total, fn(:sum, row_sums)
```

Input JSON:

```json
{ "rows": [[1, 2], [3, 4]] }
```

Each nested array still needs a child name. There is no nameless
`array :rows do array do ... end end` form.

### Hash with Declared Fields

```kumi
input do
  hash :config do
    string :app_name
    array :servers do
      hash :server do
        string :hostname
        integer :port
      end
    end
  end
end

value :name, input.config.app_name
value :ports, input.config.servers.server.port
value :port_total, fn(:sum, input.config.servers.server.port)
```

Input JSON:

```json
{
  "config": {
    "app_name": "portal",
    "servers": [
      { "hostname": "a", "port": 3000 },
      { "hostname": "b", "port": 3001 }
    ]
  }
}
```

Declare fields when you want dot-path access.

### Bare Hash Pass-Through

```kumi
input do
  hash :metadata
end

value :metadata, input.metadata
```

This treats `metadata` as a scalar object. You can pass it through or return it,
but `input.metadata.some_field` is not a declared path. Declare a `hash do ...
end` shape when you need field access.

### Hash Containing Arrays

```kumi
input do
  hash :order do
    string :id
    array :items do
      hash :item do
        integer :quantity
        decimal :unit_price
      end
    end
  end
end

value :line_totals, input.order.items.item.quantity * input.order.items.item.unit_price
value :subtotal, fn(:sum, line_totals)
```

This mirrors JSON shaped like:

```json
{
  "order": {
    "id": "A-100",
    "items": [
      { "quantity": 2, "unit_price": "10.00" }
    ]
  }
}
```

### Array of Hashes Containing Arrays

```kumi
input do
  array :orders do
    hash :order do
      string :id
      array :items do
        hash :item do
          integer :quantity
          integer :unit_price
        end
      end
      decimal :shipping_cost
    end
  end
end

value :order_subtotals, fn(:sum, input.orders.order.items.item.quantity * input.orders.order.items.item.unit_price)
value :order_totals, order_subtotals + input.orders.order.shipping_cost
value :revenue, fn(:sum, order_totals)
```

`fn(:sum, ...)` reduces the innermost axis first, so
`order_subtotals` is one value per order. A second `fn(:sum, order_totals)`
reduces orders to a scalar.

## Index Names Are Not Fields

`index:` names an axis position, not an element.

```kumi
input do
  array :rows, index: :i do
    array :cols, index: :j do
      integer :cell
    end
  end
end

value :row_major, index(:i) * fn(:array_size, input.rows.cols) + index(:j)
```

Use `index(:i)`, not `input.rows.i`. The element path is still
`input.rows.cols.cell`.

## Expression Arrays Are Tuples

This is an expression array:

```kumi
value :coords, [input.x, input.y]
```

It is not an input declaration. Internally it is a tuple expression.

Tuples are useful for small local folds:

```kumi
value :bounded_high, fn(:max, [input.low, input.high, 0])
```

They can also be vectorized. If `selected` and `input.points.point.x` both live
per point, this computes a small max per point:

```kumi
trait :x_large, input.points.point.x > 100
value :selected, select(x_large, input.points.point.x, input.points.point.y)
value :max_per_point, fn(:max, [selected, input.points.point.x])
value :total, fn(:sum, max_per_point)
```

## Expression Hashes Build Output Objects

This is an output object:

```kumi
value :meta, {
  render: "grid2d",
  size: { width: input.width, height: input.height },
  palette: { "0" => "#0f1219", "1" => "#10b981" }
}
```

Text hash keys must be static:

```kumi
{ name: input.name }        # symbol key :name
{ :name => input.name }     # symbol key :name
{ "name" => input.name }    # string key "name"
```

Use hashes to package several values that share a scope. If hash values live
per item, the result is an array of objects:

```kumi
input do
  array :users do
    hash :user do
      string :name
      string :state
    end
  end
end

value :users, {
  name: input.users.user.name,
  state: input.users.user.state
}
```

That output has one record per user.

## Cascades

Portable cascades use named traits as conditions:

```kumi
trait :high, input.score >= 90
trait :passing, input.score >= 60

value :grade do
  on high, "A"
  on passing, "P"
  base "F"
end
```

Multiple conditions in one `on` line mean all conditions must match:

```kumi
on high_performer, senior, top_team, input.salary * 0.30
```

Prefer traits even when the text parser can parse a direct expression in an
`on` condition. The Ruby cascade builder requires bare trait identifiers and
will reject function calls or comparisons there.

## Imports

Text schemas may place imports before the schema:

```kumi
import :subtotal, from: Kumi::TestSharedSchemas::Subtotal

schema do
  input do
    array :items do
      hash :item do
        integer :quantity
        integer :unit_price
      end
    end
  end

  value :total, subtotal(items: input.items)
end
```

Embedded Ruby schemas should put imports inside `schema do`:

```ruby
schema do
  import :subtotal, from: MySchemas::Subtotal
  # ...
end
```

Imported declarations use keyword mappings. The mapping values are expressions,
so vectorized calls are valid:

```kumi
value :item_tax, tax(amount: input.items.item.price)
value :tax_total, fn(:sum, item_tax)
```

## Common Post-Parse Errors

These examples parse, then fail during analysis.

### Array With No Child

```kumi
input do
  array :items
end
```

Fix:

```kumi
array :items do
  hash :item do
    decimal :price
  end
end
```

### Array With Several Children

```kumi
array :items do
  decimal :price
  integer :quantity
end
```

Fix by wrapping fields in a single element:

```kumi
array :items do
  hash :item do
    decimal :price
    integer :quantity
  end
end
```

### Index Name Used as a Field

```kumi
array :items, index: :i do
  integer :price
end

value :bad, input.items.i
```

Fix:

```kumi
value :position, index(:i)
value :price, input.items.price
```

### Sibling Arrays Combined Directly

```kumi
value :bad, input.products.product.price * input.orders.order.quantity
```

Two independent arrays cannot be implicitly zipped or multiplied all-pairs.
Use a shared nested shape, import mapping at the right scope, `outer` for
different-array all-pairs, or a deliberate future zip-style operation if one is
added.

### Scalar Passed to `cross` or `outer`

```kumi
value :bad, cross(input.price)
```

`cross` and `outer` require array-scoped expressions. Use them on a value like
`input.items.item.price`.

### Function Option Is an Expression

```kumi
value :bad, shift(input.cells.value, 1, axis_offset: input.axis)
```

Function options are raw literals, not expressions. Use constants such as
`axis_offset: 1` and `policy: :clamp`.

## Practical Rules

- Name every array element.
- Use `hash :item do ... end` when an array element has several fields.
- Use bare `hash :metadata` only as a pass-through object.
- Use `fn(:not, expr)` for portable negation.
- Use traits as cascade conditions.
- Think in axes: elementwise expressions keep axes, reductions remove the
  innermost axis, and scalar values broadcast down to child axes.
- Treat parser errors and analyzer errors separately when debugging. The parser
  checks source shape; the analyzer checks whether the schema makes sense.
