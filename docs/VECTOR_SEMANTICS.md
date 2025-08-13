# Kumi Vector Semantics — Short Guide

This note documents how Kumi handles **vectorized traversal** over **arbitrary nested objects**, how **alignment/broadcasting** works, and how **reducers** and **structure functions** behave. It’s intentionally concise but hits all the sharp edges.

---

## Terminology

* **Path** – a dot-separated traversal, e.g. `input.regions.offices.employees.salary`.
* **Scope (axes)** – the list of array segments encountered along a path.
  Example: for `regions.offices.employees.salary` the scope is `[:regions, :offices, :employees]`.
* **Rank** – number of axes = `scope.length`.
* **Index tuple** – lexicographic coordinates per axis, e.g. `[region_i, office_j, employee_k]`.

**Three Laws (think of them as invariants):**

1. **Enumeration**
   `each_indexed(path).map(&:first) == ravel(path)`

2. **Reconstruction**
   `lift(to_scope, each_indexed(path))` regroups by `to_scope` (must be a prefix of `scope(path)`).

3. **Counting**
   `size(path) == ravel(path).length == each_indexed(path).count`

These laws are the mental model. Everything else is just mechanics.

---

## Access Modes

Kumi’s Access Planner emits low-level ops (`enter_hash`, `enter_array`) and supports three vector modes per path:

### 1) `:materialize`

Return the **original nested structure** down to that path (no enumeration).
Good for “give me the data shaped like the input.”

```ruby
# Input (object mode)
{
  regions: [
    { name: "E", offices: [{ employees: [{salary: 100}, {salary: 120}] }] },
    { name: "D", offices: [{ employees: [{salary: 90}] }] }
  ]
}

materialize("regions.offices.employees.salary")
# => [[ [100,120] ], [ [90] ]]
```

### 2) `:ravel`

**Enumerate elements at the next array boundary** for that path, i.e., “collect the items at this depth.”
It is **not** NumPy’s “flatten everything.” It collects the next level.

```ruby
ravel("regions")                          # => [ {…E…}, {…D…} ]          (enumerate regions)
ravel("regions.offices")                  # => [ {employees:[…]}, {employees:[…]} ] (each office)
ravel("regions.offices.employees.salary") # => [ [100,120], [90] ]       (each employee group at that depth)
```

### 3) `:each_indexed`

Enumerate leaf values **with** their index tuple (authoritative for `lift` and alignment):

```ruby
each_indexed("regions.offices.employees.salary")
# => [
#   [100, [0,0,0]], [120, [0,0,1]],
#   [ 90, [1,0,0]]
# ]
```

---

## Lift (Regroup by prefix)

`lift(to_scope)` turns a vector-of-rows (from `each_indexed`) into a nested array grouped by `to_scope`.

```ruby
# Given values from each_indexed above:
lift([:regions],   …) # => [ [100,120], [90] ]
lift([:regions,:offices], …) # => [ [[100,120]], [[90]] ]
lift([:regions,:offices,:employees], …) # => [ [[[100,120]]], [[[90]]] ]
```

* `to_scope` must be a **prefix** of the vector’s `scope`.
* Depth is derived mechanically from index arity; VM doesn’t guess.

---

## Alignment & Broadcasting

When mapping a function over multiple arguments, Kumi:

1. Picks a **carrier** vector (the one with the longest scope).
2. **Aligns** other vectors to the carrier if they are **prefix-compatible** (same axes prefix).
3. **Broadcasts** scalars across the carrier.

If scopes aren’t prefix-compatible, lowering raises:
`cross-scope map without join: [:a] vs [:b,:c]`

```ruby
# price, quantity both scope [:items]
final = price * quantity             # zip by position (same scope)

# Broadcast scalar across [:items]
discounted = price * 0.9

# Align prefix [:regions] to carrier [:regions,:offices]
aligned_tax = align_to(offices_subtotals, regions_tax)
total = offices_subtotals * (1 - aligned_tax)
```

---

## Structure Functions vs Reducers

* **Reducers** collapse a vector to a **scalar** (e.g., `sum`, `min`, `avg`).
  Lowering selects a vector argument and emits a `Reduce`.

* **Structure functions** observe or reshape **structure** (e.g., `size`, `flatten`, `count_across`).
  Lowering usually uses a `:ravel` plan and a plain `Map` (no indices required).

### Laws for `size` and `flatten`

* `size(path) == ravel(path).length` (Counting Law)
* `flatten(path)` flattens nested arrays (by default all levels; use `flatten_one` for one level).

---

## End-to-End Mini Examples

### A. Simple vector math + reducers (object access)

```ruby
module Cart
  extend Kumi::Schema
  schema do
    input do
      array :items do
        float :price
        integer :qty
      end
      float :shipping_threshold
    end

    value :subtotals, input.items.price * input.items.qty
    value :subtotal,  fn(:sum, subtotals)
    value :shipping,  subtotal > input.shipping_threshold ? 0.0 : 9.99
    value :total,     subtotal + shipping
  end
end

data = {
  items: [{price: 100.0, qty: 2}, {price: 200.0, qty: 1}],
  shipping_threshold: 50.0
}

r = Cart.from(data)
r[:subtotals] # => [200.0, 200.0]  (vector map)
r[:subtotal]  # => 400.0           (reducer)
r[:shipping]  # => 0.0
r[:total]     # => 400.0
```

**Internal truths**:

* `each_indexed(input.items.price)` → `[[100.0,[0]],[200.0,[1]]]`
* `size(input.items)` → `2` because `ravel(input.items)` has length 2.

### B. Mixed scopes + alignment

```ruby
module Regions
  extend Kumi::Schema
  schema do
    input do
      array :regions do
        float :tax
        array :offices do
          array :employees do
            float :salary
          end
        end
      end
    end

    value :office_payrolls, fn(:sum, input.regions.offices.employees.salary)   # vector reduce per office
    value :taxed, office_payrolls * (1 - input.regions.tax) # tax (align regions.tax to [:regions,:offices])
  end
end

# Alignment rule: regions.tax (scope [:regions]) aligns to office_payrolls (scope [:regions,:offices])
```

### C. Element access (pure arrays) + structure functions

```ruby
module Cube
  extend Kumi::Schema
  schema do
    input do
      array :cube do
        element :array, :layer do
          element :array, :row do
            element :float, :cell
          end
        end
      end
    end

    value :layers,      fn(:size, input.cube)                 # == ravel(input.cube).length
    value :matrices,    fn(:size, input.cube.layer)           # enumerate at next depth
    value :rows,        fn(:size, input.cube.layer.row)
    value :all_values,  fn(:flatten, input.cube.layer.row.cell)
    value :total,       fn(:sum, all_values)
  end
end

data = { cube: [ [[1,2],[3]], [[4]] ] }

# ravel views (intuition)
# ravel(cube)                => [ [[1,2],[3]], [[4]] ]
# ravel(cube.layer)          => [ [1,2], [3], [4] ]
# ravel(cube.layer.row)      => [ 1, 2, 3, 4 ]
# ravel(cube.layer.row.cell) => [ 1, 2, 3, 4 ]  (same leaf)

c = Cube.from(data)
c[:layers]     # => 2
c[:matrices]   # => 3
c[:rows]       # => 4
c[:all_values] # => [1,2,3,4]
c[:total]      # => 10
```

---

## Planner & VM: Who does what?

* **Planner**: Emits deterministic `enter_hash`/`enter_array` sequences per path and mode.

  * For element edges (inline array aliases), it **does not** emit `enter_hash`.
  * For `:each_indexed` / `:ravel`, it appends a terminal `enter_array` **only if** the final node is an array.
* **Lowerer**: Decides plans (`:ravel`, `:each_indexed`, `:materialize`), inserts `align_to`, emits `lift` at declaration boundary when a vector result should be exposed as a scalar nested array.
* **VM**: Purely mechanical:

  * `broadcast_scalar` for scalar→vec expansion,
  * `zip_same_scope` when scopes match,
  * `align_to` for prefix alignment,
  * `group_rows` inside `lift` to reconstruct prefixes.

No type sniffing or guesses: the IR is the source of truth.

---

## Jagged & Sparse Arrays

* Ordering is **lexicographic by index tuple** (stable).
* No padding is introduced; missing branches are just… missing.
* `align_to(..., on_missing: :error|:nil)` enforces policy.

---

## Error Policies

For missing keys/arrays, accessors obey policy:

* `:error` (default) – raise descriptive error with the path/mode.
* `:skip` – drop the missing branch (useful in ravels).
* `:yield_nil` – emit `nil` in place (preserves cardinality).

Document these on any user-facing accessor.

---

## Quick Cheatsheet

* Use **`ravel(path)`** to “list the things at this level.”
* Use **`each_indexed(path)`** when you need `(value, idx)` pairs for joins/regroup.
* Use **`lift(to_scope, each_indexed(path))`** to reconstruct nested structure.
* **Reducers** (e.g., `sum`, `avg`, `min`) consume the raveled view of their argument.
* **Structure functions** (e.g., `size`, `flatten`, `flatten_one`, `count_across`) operate on structure at that depth and usually compile via `:ravel`.

Keep the three laws in mind and Kumi’s behavior is predictable—even over deeply nested, heterogeneous data.