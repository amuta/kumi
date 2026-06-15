# Kumi Input Shapes

The `input do … end` block declares the shape of the data a schema runs on:
scalars, arrays, hashes, and any nesting of them. Every value referenced in the
body (`input.foo.bar`) must trace back to a declaration here.

This is the reference for declaring inputs. For the rest of the language
(declarations, operators, functions, control flow) see [SYNTAX.md](SYNTAX.md).

## The element rule: always name the element

Kumi **maps over arrays by default** (unless you `zip`). The single child inside
an `array` block names the element that the map binds and iterates over — so the
element must always be named. Every `array` declares **exactly one child**:

- a primitive (`integer :value`) for a **scalar array**,
- a `hash` (`hash :item do … end`) when each element has **several fields**,
- a nested `array` for an **array of arrays**.

There is no childless/nameless array — without a name there is nothing for the
map to bind. Omitting the child is an error that tells you exactly this.

`index: :i` is **not** the element — it names the **axis/position** so you can
read the index value with `index(:i)`. You do *not* write `input.cells.i` to
reach the element; the element is the named child (`input.cells.value`) or the
broadcast array itself (`input.cells`).

## Scalars

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

## Arrays

Arrays represent sequences. Navigate using dot notation through each level.
Remember the [element rule](#the-element-rule-always-name-the-element): each
`array` declares exactly one named child.

**1D Array (scalar elements):**
```kumi
input do
  array :cells do
    integer :value     # `value` names the element
                       # Access: input.cells.value  (maps elementwise)
                       #         input.cells         (whole array, e.g. fn(:size, …))
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

## Arrays of Hashes

Common pattern for structured collections — use a `hash` child when each element
has several fields:

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

## Hashes

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

## Arrays with Named Indices

`index:` names an axis so you can read its **position** with `index(:name)`. It
is independent of the element — you still name the element child (here the
placeholder `integer :_`, since only the positions are used). `index(:i)` reads
the position; it is never an element accessor (`input.x.i` is not a thing).

```kumi
input do
  array :x, index: :i do
    array :y, index: :j do
      integer :_           # element child (value unused, only positions matter)
    end
  end
end

# Use in expressions
let :W, fn(:array_size, input.x.y)
value :row_major, (index(:i) * W) + index(:j)
value :col_major, (index(:j) * fn(:array_size, input.x)) + index(:i)
```

## See also

- [SYNTAX.md](SYNTAX.md) — declarations, operators, functions, control flow.
- All-pairs over arrays: `cross` (one array, A × A') and `outer` (two arrays,
  A × B) in [SYNTAX.md](SYNTAX.md#all-pairs-cross).
