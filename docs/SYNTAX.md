# Kumi Syntax — Quick Reference & Guide

## Quick Reference

### File Structure
```kumi
schema do
  input do
    # Input shape declarations
  end

  # Declarations: let, value, trait
end
```

### Types
```kumi
integer    # Integer numbers
float      # Floating point numbers
decimal    # Precise decimal numbers (money, bignum calculations)
string     # Text strings
array      # Sequential collections
hash       # Structured objects
```

### Declarations
```kumi
let   :name, expr    # Intermediate value
value :name, expr    # Output value
trait :name, expr    # Boolean mask
```

### Operators

**Arithmetic:** `+` `-` `*` `/` `**` `%`
**Comparison:** `>` `>=` `<` `<=` `==` `!=`
**Boolean:** `&` (AND) `|` (OR)
**Indexing:** `tuple[0]` `tuple[1]` ...

### Aggregation Functions

| Function | Description | Example |
|----------|-------------|---------|
| `fn(:sum, arr)` | Sum all elements | `fn(:sum, input.items.item.price)` |
| `fn(:count, arr)` | Count elements | `fn(:count, input.items.item.price)` |
| `fn(:max, arr)` | Maximum value | `fn(:max, input.items.item.price)` |
| `fn(:min, arr)` | Minimum value | `fn(:min, input.items.item.price)` |
| `fn(:mean, arr)` | Average (aliases: `avg`) | `fn(:mean, input.scores.score)` |
| `fn(:sum_if, vals, cond)` | Sum where condition is true | `fn(:sum_if, input.items.item.price, expensive)` |
| `fn(:count_if, vals, match)` | Count matching values | `fn(:count_if, input.cells.value, 0)` |
| `fn(:mean_if, vals, cond)` | Average where true (aliases: `avg_if`) | `fn(:mean_if, input.scores.score, passing)` |
| `fn(:any, arr)` | True if any element true | `fn(:any, input.flags.active)` |
| `fn(:all, arr)` | True if all elements true | `fn(:all, input.checks.passed)` |
| `fn(:join, arr)` | Join strings | `fn(:join, input.words.word)` |

### Elementwise Functions

**Arithmetic:**
- `fn(:abs, x)` — Absolute value
- `fn(:clamp, x, lo, hi)` — Clamp to range

**Type Conversion:**
- `fn(:to_decimal, x)` — Convert to decimal
- `fn(:to_integer, x)` — Convert to integer
- `fn(:to_float, x)` — Convert to float
- `fn(:to_string, x)` — Convert to string

**String:**
- `fn(:concat, s1, s2)` — Concatenate strings
- `fn(:upcase, str)` — Convert to uppercase
- `fn(:downcase, str)` — Convert to lowercase
- `fn(:length, str)` — String length (aliases: `len`, `size`)

**Array:**
- `fn(:array_size, arr)` — Array length (alias: `size`)
- `fn(:at, arr, idx)` — Get element at index (alias: `[]`)

**Hash:**
- `fn(:fetch, key)` — Fetch value from hash

### Control Flow
```kumi
# Simple selection
select(condition, if_true, if_false)

# Multi-way cascade (first match wins)
value :result do
  on cond1, cond2, expr1    # If cond1 AND cond2
  on cond3, expr2           # Else if cond3
  base expr3                # Else (default)
end
```

### Spatial Operations
```kumi
# Shift — access neighbors
shift(expr, offset, axis_offset: 0, policy: :zero)
  # offset: -N (left/up), +N (right/down)
  # axis_offset: 0 (innermost/x), 1 (next/y)
  # policy: :zero (default) | :wrap | :clamp

# Roll — rotate with wrapping
roll(expr, offset, policy: :wrap)
  # policy: :wrap (default) | :clamp

# Index access
index(:name)  # Get index value (requires array declared with index: :name)
```

### Common Patterns

**Filter and aggregate:**
```kumi
trait :expensive, input.items.item.price > 100.0
value :expensive_total, fn(:sum_if, input.items.item.price, expensive)
```

**Map then reduce:**
```kumi
value :subtotals, input.items.item.price * input.items.item.quantity
value :total, fn(:sum, subtotals)
```

**Broadcasting (parent to child):**
```kumi
value :dept_total, fn(:sum, input.depts.dept.teams.team.headcount)
trait :large_team, input.depts.dept.teams.team.headcount > dept_total / 3
```

**Index-based calculation:**
```kumi
let :W, fn(:array_size, input.x.y)
value :row_major, (index(:i) * W) + index(:j)
```

---

## Detailed Guide

### 1) Input Shapes

#### Scalars

Scalar inputs represent single values:

```kumi
input do
  integer :x
  float :rate
  decimal :price        # Precise decimal for money calculations
  string :name
end
```

**Example:**
```kumi
schema do
  input do
    integer :x
    integer :y
  end

  value :sum, input.x + input.y
  value :product, input.x * input.y
end
```

#### Arrays

Arrays represent sequences. Navigate using dot notation through each level.

**1D Array:**
```kumi
input do
  array :cells do
    integer :value     # Access: input.cells.value
  end
end
```

**2D Array (grid):**
```kumi
input do
  array :rows do
    array :col do
      integer :v       # Access: input.rows.col.v
    end
  end
end
```

**3D Array (cube):**
```kumi
input do
  array :cube do
    array :layer do
      array :row do
        integer :cell  # Access: input.cube.layer.row.cell
      end
    end
  end
end
```

#### Arrays of Hashes

Common pattern for structured collections:

```kumi
input do
  array :items do
    hash :item do
      float :price
      integer :quantity
      string :category
    end
  end
end

# Access: input.items.item.price
#         input.items.item.quantity
```

#### Hashes

Hashes represent structured data with named fields:

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

# Access scalar: input.config.app_name
# Access nested: input.config.servers.server.hostname
```

#### Arrays with Named Indices

Declare indices to access position values:

```kumi
input do
  array :x, index: :i do
    array :y, index: :j do
      integer :_           # Placeholder (value unused)
    end
  end
end

# Use in expressions
let :W, fn(:array_size, input.x.y)
value :row_major, (index(:i) * W) + index(:j)
value :col_major, (index(:j) * fn(:array_size, input.x)) + index(:i)
```

### 2) Declarations

#### `let` — Intermediate Values

Use for computed values referenced elsewhere:

```kumi
let :x_sq, input.x * input.x
let :y_sq, input.y * input.y
let :distance_sq, x_sq + y_sq
value :distance, distance_sq ** 0.5
```

#### `value` — Outputs

Results serialized to output:

```kumi
value :cart_total, fn(:sum, input.items.item.price * input.items.item.quantity)
value :item_count, fn(:count, input.items.item.quantity)
```

#### `trait` — Boolean Masks

Boolean conditions for filtering/branching:

```kumi
trait :expensive_items, input.items.item.price > 100.0
trait :electronics, input.items.item.category == "electronics"
trait :high_value, expensive_items & electronics

value :discounted, select(high_value,
  input.items.item.price * 0.8,
  input.items.item.price
)
```

### 3) Operators

**Arithmetic:**
```kumi
+   -   *   /   **   %

value :total, input.x + input.y
value :area, input.width * input.height
value :power, input.base ** input.exponent
value :remainder, input.x % input.y
```

**Comparison:**
```kumi
>   >=   <   <=   ==   !=

trait :is_adult, input.age >= 18
trait :is_expensive, input.price > 100.0
trait :exact_match, input.category == "electronics"
```

**Boolean:**
```kumi
&   |   !

trait :premium, is_adult & is_expensive
trait :eligible, is_member | is_trial
trait :not_active, !is_active
```

### 3) Schema Imports

Reuse declarations from other schemas without duplicating code.

#### Basic Import

```kumi
import :tax, from: MySchemas::TaxCalculator

schema do
  input do
    decimal :amount
  end

  # Call imported declaration with input mapping
  value :total, tax(amount: input.amount)
end
```

#### Multiple Imports

```kumi
import :tax, :discount, from: MySchemas::Utilities

schema do
  input do
    decimal :price
  end

  value :after_tax, tax(amount: input.price)
  value :final, discount(amount: after_tax)
end
```

#### Nested Imports

Imported schemas can themselves import from other schemas. The compiler resolves the full chain automatically.

```kumi
# PriceSchema imports TaxSchema internally
import :final_price, from: MySchemas::PriceSchema
```

**Key Rules:**
- All imported declarations must be available when the schema loads
- Input parameters are mapped by name (no positional arguments)
- Imports work with reductions, broadcasts, and cascades like normal declarations

### 4) Functions

All functions use `fn(:name, args...)` syntax.

#### Aggregation (Reduce Dimension)

**Sum and Count:**
```kumi
value :total, fn(:sum, input.items.item.price)
value :count, fn(:count, input.items.item.price)
```

**Min, Max, Mean:**
```kumi
value :highest, fn(:max, input.items.item.price)
value :lowest, fn(:min, input.items.item.price)
value :average, fn(:mean, input.scores.score)
```

**Conditional Aggregation:**
```kumi
trait :expensive, input.items.item.price > 100.0
value :expensive_sum, fn(:sum_if, input.items.item.price, expensive)
value :expensive_avg, fn(:mean_if, input.items.item.price, expensive)
value :zero_count, fn(:count_if, input.cells.value, 0)
```

**Boolean Aggregation:**
```kumi
value :has_any_active, fn(:any, input.flags.active)
value :all_passed, fn(:all, input.checks.passed)
```

**String Aggregation:**
```kumi
value :combined, fn(:join, input.words.word)
```

#### Elementwise (No Dimension Change)

**Array Utilities:**
```kumi
value :num_rows, fn(:array_size, input.matrix.row)
value :first_item, fn(:at, input.items, 0)

let :W, fn(:array_size, input.x.y)
value :linear_idx, (index(:i) * W) + index(:j)
```

**String Operations:**
```kumi
value :full_name, fn(:concat, input.first_name, input.last_name)
value :upper, fn(:upcase, input.name)
value :lower, fn(:downcase, input.name)
value :name_len, fn(:length, input.name)
```

**Math:**
```kumi
value :magnitude, fn(:abs, input.value)
value :bounded, fn(:clamp, input.value, 0, 100)
```

### 5) Conditionals

#### Simple Selection with `select`

```kumi
trait :is_expensive, input.items.item.price > 100.0
value :discounted, select(is_expensive,
  input.items.item.price * 0.9,
  input.items.item.price
)
```

#### Multi-way Cascade with `on`

First matching condition wins:

```kumi
trait :x_positive, input.x > 0
trait :y_positive, input.y > 0

value :status do
  on y_positive, x_positive, "both positive"
  on x_positive,             "x positive"
  on y_positive,             "y positive"
  base                       "neither positive"
end
```

**Complex Example with Broadcasting:**
```kumi
trait :high_performer, input.employees.employee.rating >= 4.5
trait :senior, input.employees.employee.level == "senior"
trait :top_team, input.teams.team.performance_score >= 0.9

value :bonus do
  on high_performer, senior, top_team, input.employees.employee.salary * 0.30
  on high_performer, top_team,         input.employees.employee.salary * 0.20
  base                                 input.employees.employee.salary * 0.05
end
```

### 6) Tuples and Indexing

#### Tuple Literals

```kumi
value :scores, [100, 85, 92]
value :coords, [input.x, input.y]
value :mixed, [1, input.x + 10, input.y * 2]
```

#### Tuple Indexing

```kumi
value :scores, [100, 85, 92]
value :first, scores[0]
value :second, scores[1]
value :third, scores[2]
```

#### Operations on Tuples

```kumi
value :coords, [input.x, input.y, input.z]
value :max_coord, fn(:max, coords)
value :sum_coords, fn(:sum, coords)
```

#### Vectorized Tuple Operations

When tuples contain array elements:

```kumi
trait :x_large, input.points.point.x > 100
value :selected, select(x_large,
  input.points.point.x,
  input.points.point.y
)

# For each point, compute max of selected and x
value :max_per_point, fn(:max, [selected, input.points.point.x])
```

### 7) Spatial Operations

#### `shift` — Access Neighbors

Move along arrays to access adjacent values.

**Syntax:**
```kumi
shift(expr, offset, axis_offset: 0, policy: :zero)
```

**Parameters:**
- `offset`: Distance to shift (negative = left/up, positive = right/down)
- `axis_offset`: Which dimension (0 = innermost/x, 1 = next/y, etc.)
- `policy`: Edge handling
  - `:zero` (default) — Use 0 for out-of-bounds
  - `:wrap` — Wrap to opposite edge
  - `:clamp` — Repeat edge value

**1D Example:**
```kumi
input do
  array :cells do
    integer :value
  end
end

value :left,  shift(input.cells.value, -1)
value :right, shift(input.cells.value,  1, policy: :wrap)
```

**2D Example (Game of Life):**
```kumi
let :a, input.rows.col.alive

# Horizontal (axis_offset: 0, default)
let :w, shift(a, -1)                  # West
let :e, shift(a,  1)                  # East

# Vertical (axis_offset: 1)
let :n, shift(a, -1, axis_offset: 1)  # North
let :s, shift(a,  1, axis_offset: 1)  # South

# Diagonals (shift twice)
let :nw, shift(n, -1)
let :ne, shift(n,  1)
let :sw, shift(s, -1)
let :se, shift(s,  1)

let :neighbors, fn(:sum, [n, s, w, e, nw, ne, sw, se])
```

#### `roll` — Rotate with Wrapping

Convenience for 1D rotations:

```kumi
value :roll_right, roll(input.cells.value,  1)                    # Wrap (default)
value :roll_left,  roll(input.cells.value, -1)
value :roll_clamp, roll(input.cells.value,  1, policy: :clamp)
```

### 8) Reductions and Broadcasting

#### Reductions

Aggregation functions reduce dimensionality:

**1D → Scalar:**
```kumi
value :total, fn(:sum, input.items.item.price)
```

**2D → 1D (reduce inner dimension):**
```kumi
value :row_sums, fn(:sum, input.rows.col.v)
```

**2D → Scalar (double reduction):**
```kumi
value :grand_total, fn(:sum, fn(:sum, input.rows.col.v))
```

**3D → Scalar (triple reduction):**
```kumi
trait :over_limit, input.cube.layer.row.cell > 100
value :sum_over, fn(:sum_if, input.cube.layer.row.cell, over_limit)
value :total, fn(:sum, fn(:sum, sum_over))
```

#### Broadcasting

Values at higher/parent levels automatically broadcast to lower/child levels.

**Scalar to Array:**
```kumi
input do
  array :items do
    hash :item do
      float :price
    end
  end
  float :discount  # Scalar
end

# discount broadcasts to each item
value :discounted, input.items.item.price * (1.0 - input.discount)
```

**Parent Level to Child Level:**
```kumi
input do
  array :departments do
    hash :dept do
      array :teams do
        hash :team do
          integer :headcount
        end
      end
    end
  end
end

# Reduce to department level
value :dept_total, fn(:sum, input.departments.dept.teams.team.headcount)

# dept_total broadcasts to team level
trait :large_team, input.departments.dept.teams.team.headcount > dept_total / 3
```

**Key Rule:** Axes align by identity (lineage), not name. A department-level value knows which teams belong to it.

### 9) Common Patterns

#### Filter and Aggregate

```kumi
trait :expensive, input.items.item.price > 100.0
value :expensive_total, fn(:sum_if, input.items.item.price, expensive)
value :expensive_count, fn(:sum_if, 1, expensive)
```

#### Map then Reduce

```kumi
value :subtotals, input.items.item.price * input.items.item.quantity
value :cart_total, fn(:sum, subtotals)
```

#### Conditional Aggregation in Hierarchies

```kumi
trait :over_limit, input.cube.layer.row.cell > 100
value :cell_sum, fn(:sum_if, input.cube.layer.row.cell, over_limit)
value :total, fn(:sum, fn(:sum, cell_sum))
```

#### Hash Construction

```kumi
value :users, {
  name: input.users.user.name,
  state: input.users.user.state
}

trait :is_john, input.users.user.name == "John"
value :john_user, select(is_john, users, "NOT_JOHN")
```

#### Index-Based Calculations

```kumi
input do
  array :x, index: :i do
    array :y, index: :j do
      integer :_
    end
  end
end

let :W, fn(:array_size, input.x.y)
value :row_major, (index(:i) * W) + index(:j)
value :col_major, (index(:j) * fn(:array_size, input.x)) + index(:i)
value :coord_sum, index(:i) + index(:j)
```

---

## Complete Examples

### Shopping Cart with Discounts

```kumi
schema do
  input do
    array :items do
      hash :item do
        float :price
        integer :qty
      end
    end
    float :discount
  end

  value :items_subtotal, input.items.item.price * input.items.item.qty
  value :items_discounted, input.items.item.price * (1.0 - input.discount)

  value :items_is_big, input.items.item.price > 100.0
  value :items_effective, select(items_is_big,
    items_subtotal * 0.9,
    items_subtotal
  )

  value :total_qty, fn(:sum, input.items.item.qty)
  value :cart_total, fn(:sum, items_subtotal)
  value :cart_total_effective, fn(:sum, items_effective)
end
```

### Conway's Game of Life

```kumi
schema do
  input do
    array :rows do
      array :col do
        integer :alive  # 0 or 1
      end
    end
  end

  let :a, input.rows.col.alive

  let :n,  shift(a, -1, axis_offset: 1)
  let :s,  shift(a,  1, axis_offset: 1)
  let :w,  shift(a, -1)
  let :e,  shift(a,  1)
  let :nw, shift(n, -1)
  let :ne, shift(n,  1)
  let :sw, shift(s, -1)
  let :se, shift(s,  1)

  let :neighbors, fn(:sum, [n, s, w, e, nw, ne, sw, se])

  let :alive, a > 0
  let :n3_alive, neighbors == 3
  let :n2_alive, neighbors == 2
  let :keep_alive, n2_alive & alive
  let :next_alive, n3_alive | keep_alive

  value :next_state, select(next_alive, 1, 0)
end
```

### Hierarchical Organization Analysis

```kumi
schema do
  input do
    array :departments do
      hash :dept do
        string :dept_name
        array :teams do
          hash :team do
            string :team_name
            integer :headcount
          end
        end
      end
    end
  end

  value :dept_headcount, fn(:sum, input.departments.dept.teams.team.headcount)
  value :teams_per_dept, fn(:count, input.departments.dept.teams.team.team_name)
  value :avg_headcount_per_dept, dept_headcount / teams_per_dept

  trait :is_above_average_team,
    input.departments.dept.teams.team.headcount > avg_headcount_per_dept
end
```

---

## Best Practices

**Do:**
- Use `trait` for boolean conditions
- Use `fn(:array_size, ...)` instead of hardcoding lengths
- Name intermediate values with `let` for clarity
- Think about which dimension you're reducing
- Remember axes align by lineage, not name

**Don't:**
- Forget that aggregation functions reduce dimensionality
- Hardcode array sizes
- Mix up `axis_offset` values (0 = inner/x, 1 = outer/y)
