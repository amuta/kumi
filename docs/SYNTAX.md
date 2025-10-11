# Kumi Syntax — Practical Guide

A practical reference for writing Kumi schemas, organized by common patterns and use cases.

## Table of Contents
1. [File Structure](#1-file-structure)
2. [Input Shapes](#2-input-shapes)
3. [Declarations](#3-declarations)
4. [Expressions](#4-expressions)
5. [Functions (Kernels)](#5-functions-kernels)
6. [Conditionals](#6-conditionals)
7. [Tuples and Indexing](#7-tuples-and-indexing)
8. [Spatial Operations](#8-spatial-operations)
9. [Reductions and Broadcasting](#9-reductions-and-broadcasting)
10. [Common Patterns](#10-common-patterns)
11. [Complete Examples](#11-complete-examples)

## 1) File Structure

Every Kumi schema follows this basic skeleton:

```kumi
schema do
  input do
    # Declare your input shape here
  end

  # Declare computed values here (let, value, trait)
end
```

## 2) Input Shapes

### Scalars

Scalar inputs represent single values:

```kumi
input do
  integer :x        # Single integer
  float   :rate     # Single float
  string  :name     # Single string
end
```

**Example: Simple math**
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

### Arrays

Arrays represent sequences of values. Elements can be scalars, hashes, or nested arrays.

**1D Arrays:**
```kumi
input do
  array :cells do
    integer :value     # Access: input.cells.value
  end
end
```

**2D Arrays (grids):**
```kumi
input do
  array :rows do
    array :col do
      integer :v       # Access: input.rows.col.v
    end
  end
end
```

**3D Arrays (cubes):**
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

### Arrays of Hashes

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
```

### Hashes

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

# Access scalar field: input.config.app_name
# Access array within hash: input.config.servers.server.hostname
```

### Arrays with Named Indices

Use `index: :name` to access positional indices in expressions:

```kumi
input do
  array :x, index: :i do
    array :y, index: :j do
      integer :_           # Placeholder when value doesn't matter
    end
  end
end

# Compute row-major index
value :box, (index(:i) * fn(:array_size, input.x.y)) + index(:j)
```

## 3) Declarations

Kumi has three types of declarations:

### `let` — Intermediate Values

Use `let` for computed values that you'll reference in other expressions:

```kumi
let :x_sq, input.x * input.x
let :y_sq, input.y * input.y
let :distance_sq, x_sq + y_sq
value :distance, distance_sq ** 0.5
```

### `value` — Outputs

Use `value` for results that will be serialized in the output:

```kumi
value :cart_total, fn(:sum, input.items.item.price * input.items.item.quantity)
value :item_count, fn(:count, input.items.item.quantity)
```

### `trait` — Boolean Masks

Use `trait` for boolean conditions used in filtering or conditional logic:

```kumi
trait :expensive_items, input.items.item.price > 100.0
trait :electronics, input.items.item.category == "electronics"
trait :high_value, expensive_items & electronics

value :discounted_price, select(high_value, input.items.item.price * 0.8, input.items.item.price)
```

## 4) Expressions

### Accessing Input

Navigate input structures using dot notation:

```kumi
input.x                                    # Scalar field
input.items.item.price                     # Array element field
input.config.app_name                      # Hash field
input.departments.dept.teams.team.name     # Nested hierarchy
```

### Arithmetic Operators

```kumi
+   -   *   /         # Basic math
**                    # Exponentiation
( )                   # Grouping

# Examples
value :total, input.x + input.y
value :area, input.width * input.height
value :hypotenuse, (input.x ** 2 + input.y ** 2) ** 0.5
```

### Comparison Operators

```kumi
>   >=   <   <=   ==   !=

# Examples
trait :is_adult, input.age >= 18
trait :is_expensive, input.price > 100.0
trait :exact_match, input.category == "electronics"
```

### Boolean Operators

```kumi
&   # AND
|   # OR

# Examples
trait :premium, is_adult & is_expensive
trait :eligible, is_member | is_trial
```

## 5) Functions (Kernels)

Functions are called using `fn(:name, args...)` syntax.

### Aggregation Functions

**`fn(:sum, array)`** — Sum all elements
```kumi
value :total_price, fn(:sum, input.items.item.price)
value :grand_total, fn(:sum, fn(:sum, input.matrix.row.cell))  # 2D sum
```

**`fn(:count, array)`** — Count elements
```kumi
value :num_items, fn(:count, input.items.item.price)
```

**`fn(:max, array)` / `fn(:min, array)`** — Maximum/minimum value
```kumi
value :highest_price, fn(:max, input.items.item.price)
value :lowest_score, fn(:min, scores)
```

### Conditional Aggregation

**`fn(:sum_if, values, condition)`** — Sum where condition is true
```kumi
trait :expensive, input.items.item.price > 100.0
value :expensive_total, fn(:sum_if, input.items.item.price, expensive)
```

**`fn(:count_if, values, match_value)`** — Count matching values
```kumi
value :zero_count, fn(:count_if, input.cells.value, 0)
```

### Array Utilities

**`fn(:array_size, array)`** — Get array length at that dimension
```kumi
value :num_rows, fn(:array_size, input.matrix.row)
value :num_cols, fn(:array_size, input.matrix.row.col)

# Use in calculations
let :W, fn(:array_size, input.x.y)
value :linear_index, (index(:i) * W) + index(:j)
```

## 6) Conditionals

### Elementwise Selection with `select`

Use `select(condition, if_true, if_false)` for simple branching:

```kumi
trait :is_expensive, input.items.item.price > 100.0
value :discounted, select(is_expensive,
  input.items.item.price * 0.9,
  input.items.item.price
)
```

### Cascaded Conditions with `on`

Use `value ... do on ... end` for multiple conditions. First matching condition wins:

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

**Complex example with broadcasts:**
```kumi
trait :high_performer, input.teams.team.employees.employee.rating >= 4.5
trait :senior_level, input.teams.team.employees.employee.level == "senior"
trait :top_team, input.teams.team.performance_score >= 0.9

value :bonus do
  on high_performer, senior_level, top_team, input.teams.team.employees.employee.salary * 0.30
  on high_performer, top_team,                input.teams.team.employees.employee.salary * 0.20
  base                                        input.teams.team.employees.employee.salary * 0.05
end
```

## 7) Tuples and Indexing

### Tuple Literals

Create fixed-size tuples with array literal syntax:

```kumi
value :scores, [100, 85, 92]
value :combo, [input.x, input.y]
value :mixed, [1, input.x + 10, input.y * 2]
```

### Tuple Indexing

Access tuple elements by position:

```kumi
value :scores, [100, 85, 92]
value :first_score, scores[0]
value :second_score, scores[1]
value :third_score, scores[2]
```

### Operations on Tuples

Apply functions to tuples:

```kumi
value :coords, [input.x, input.y, input.z]
value :max_coord, fn(:max, coords)
value :sum_coords, fn(:sum, coords)
```

### Vectorized Operations

When tuples contain array elements, operations are vectorized:

```kumi
trait :x_large, input.points.point.x > 100
value :selected, select(x_large, input.points.point.x, input.points.point.y)

# For each point, compute max of selected value and x coordinate
value :max_per_point, fn(:max, [selected, input.points.point.x])
```

## 8) Spatial Operations

Spatial operations allow you to access neighboring values in arrays.

### `shift` — Access Offset Elements

**Syntax:** `shift(expr, offset, axis_offset: n, policy: :zero | :wrap | :clamp)`

**Parameters:**
- `offset`: How many positions to shift (negative = left/up, positive = right/down)
- `axis_offset`: Which dimension (0 = innermost/x, 1 = next level/y, etc.)
- `policy`: How to handle edges
  - `:zero` (default) — Use 0 for out-of-bounds
  - `:wrap` — Wrap around to opposite edge
  - `:clamp` — Repeat edge value

**1D Example:**
```kumi
input do
  array :cells do
    integer :value
  end
end

value :left_neighbor,  shift(input.cells.value, -1)              # Default :zero
value :right_neighbor, shift(input.cells.value,  1, policy: :wrap)
```

**2D Example (Game of Life):**
```kumi
let :a, input.rows.col.alive

# Horizontal neighbors (axis_offset: 0)
let :w, shift(a, -1)                  # West
let :e, shift(a,  1)                  # East

# Vertical neighbors (axis_offset: 1)
let :n, shift(a, -1, axis_offset: 1)  # North
let :s, shift(a,  1, axis_offset: 1)  # South

# Diagonals
let :nw, shift(n, -1)
let :ne, shift(n,  1)
let :sw, shift(s, -1)
let :se, shift(s,  1)

let :neighbors, fn(:sum, [n, s, w, e, nw, ne, sw, se])
```

### `roll` — Rotate with Wrapping

**Syntax:** `roll(expr, offset, policy: :wrap | :clamp)`

Convenience function for 1D rotations (wrap by default):

```kumi
value :roll_right, roll(input.cells.value,  1)                    # Wrap
value :roll_left,  roll(input.cells.value, -1)
value :roll_clamp, roll(input.cells.value,  1, policy: :clamp)
```

## 9) Reductions and Broadcasting

### Reductions

Aggregation functions reduce dimensionality:

**1D → Scalar:**
```kumi
input do
  array :items do
    hash :item do
      float :price
    end
  end
end

# Reduces array to single value
value :total, fn(:sum, input.items.item.price)
```

**2D → 1D:**
```kumi
input do
  array :rows do
    array :col do
      integer :v
    end
  end
end

# Sum each row (reduces inner dimension)
value :row_sums, fn(:sum, input.rows.col.v)
```

**2D → Scalar:**
```kumi
# Double reduction
value :grand_total, fn(:sum, fn(:sum, input.rows.col.v))
```

### Broadcasting

Values at higher levels automatically broadcast to lower levels when combined:

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

# dept_total broadcasts to team level for comparison
trait :large_team, input.departments.dept.teams.team.headcount > dept_total / 3
```

**Key Rule:** Axes align by identity (lineage), not by name. A value computed at department level knows which department's teams to broadcast to.

## 10) Common Patterns

### Filter and Aggregate

Use traits to filter, then aggregate matching values:

```kumi
trait :expensive, input.items.item.price > 100.0
value :expensive_total, fn(:sum_if, input.items.item.price, expensive)
value :expensive_count, fn(:sum_if, 1, expensive)
```

### Map then Reduce

Transform elements, then aggregate:

```kumi
# Calculate subtotals for each item
value :subtotals, input.items.item.price * input.items.item.quantity

# Sum all subtotals
value :cart_total, fn(:sum, subtotals)
```

### Conditional Aggregation in Hierarchies

Filter at child level, aggregate to parent:

```kumi
trait :over_limit, input.cube.layer.row.cell > 100
value :cell_sum_over_limit, fn(:sum_if, input.cube.layer.row.cell, over_limit)
value :total_over_limit, fn(:sum, fn(:sum, cell_sum_over_limit))
```

### Hash Construction

Build structured output objects:

```kumi
value :users, {
  name: input.users.user.name,
  state: input.users.user.state
}

trait :is_john, input.users.user.name == "John"
value :john_user, select(is_john, users, "NOT_JOHN")
```

### Index-Based Calculations

Use named indices for position-dependent logic:

```kumi
input do
  array :x, index: :i do
    array :y, index: :j do
      integer :_
    end
  end
end

let :W, fn(:array_size, input.x.y)

# Row-major linear index
value :row_major, (index(:i) * W) + index(:j)

# Column-major linear index
value :col_major, (index(:j) * fn(:array_size, input.x)) + index(:i)

# Simple coordinate sum
value :coord_sum, index(:i) + index(:j)
```

## 11) Complete Examples

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

  # Compute subtotals per item
  value :items_subtotal, input.items.item.price * input.items.item.qty

  # Apply discount to each item
  value :items_discounted, input.items.item.price * (1.0 - input.discount)

  # Conditional pricing
  value :items_is_big, input.items.item.price > 100.0
  value :items_effective, select(items_is_big,
    items_subtotal * 0.9,
    items_subtotal
  )

  # Final aggregations
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

  # Get 8 neighbors using shift
  let :n,  shift(a, -1, axis_offset: 1)  # North
  let :s,  shift(a,  1, axis_offset: 1)  # South
  let :w,  shift(a, -1)                  # West
  let :e,  shift(a,  1)                  # East
  let :nw, shift(n, -1)
  let :ne, shift(n,  1)
  let :sw, shift(s, -1)
  let :se, shift(s,  1)

  let :neighbors, fn(:sum, [n, s, w, e, nw, ne, sw, se])

  # Conway rules
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

  # Department-level aggregations
  value :dept_headcount, fn(:sum, input.departments.dept.teams.team.headcount)
  value :teams_per_dept, fn(:count, input.departments.dept.teams.team.team_name)
  value :avg_headcount_per_dept, dept_headcount / teams_per_dept

  # Broadcast department average back to team level
  trait :is_above_average_team,
    input.departments.dept.teams.team.headcount > avg_headcount_per_dept
end
```

## 12) Quick Reference

### Declaration Keywords
- `schema` — Root container
- `input` — Input shape declaration
- `value` — Output declaration
- `let` — Intermediate value
- `trait` — Boolean mask

### Type Keywords
- `integer`, `float`, `string` — Scalar types
- `array` — Sequential collection
- `hash` — Structured object

### Functions (fn)
- `fn(:sum, arr)` — Sum elements
- `fn(:count, arr)` — Count elements
- `fn(:max, arr)`, `fn(:min, arr)` — Min/max
- `fn(:sum_if, values, condition)` — Conditional sum
- `fn(:count_if, values, match)` — Conditional count
- `fn(:array_size, arr)` — Get array length

### Control Flow
- `select(cond, if_true, if_false)` — Ternary selection
- `value :x do on ..., ...; base ... end` — Multi-way branch

### Spatial Functions
- `shift(expr, offset, axis_offset: 0, policy: :zero)` — Access neighbors
- `roll(expr, offset, policy: :wrap)` — Rotate array
- `index(:name)` — Access named array index

### Operators
- Arithmetic: `+`, `-`, `*`, `/`, `**`
- Comparison: `>`, `>=`, `<`, `<=`, `==`, `!=`
- Boolean: `&` (AND), `|` (OR)
- Indexing: `tuple[0]`, `tuple[1]`, etc.

### Policies
- `:zero` — Use 0 for out-of-bounds (default for shift)
- `:wrap` — Wrap to opposite edge (default for roll)
- `:clamp` — Repeat edge value

### Best Practices

**Do:**
- Use `trait` for boolean conditions
- Use `fn(:array_size, ...)` instead of hardcoding lengths
- Name intermediate values with `let` for clarity
- Think about which dimension you're reducing

**Don't:**
- Forget that functions reduce dimensionality
- Hardcode array sizes
- Mix up axis_offset values (0 = inner/x, 1 = outer/y)