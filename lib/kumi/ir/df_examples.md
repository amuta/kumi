# IR::DF Examples

The goal of the DF layer is to capture SNAST semantics in a functional,
axis-aware graph before we materialize loops. These examples are derived from
golden fixtures under `golden/**/expected/snast.txt` and illustrate how real
schemas should map into DF nodes.

## Example 1 – Scalar math (`golden/simple_math`)

SNAST excerpt:

```
(VALUE sum
  (Call :core.add
    (InputRef x key_chain=[]) :: [] -> integer
    (InputRef y key_chain=[]) :: [] -> integer
  ) :: [] -> integer
) :: [] -> integer
```

DF view:

- `df.input("x")` and `df.input("y")` nodes with `axes=[]`, `dtype=integer`.
- `df.map` node with `function=:core.add`, `axes=[]`.
- Declaration result becomes a DF function returning the `df.map` value.

Because there are no axes, lowering to Loop IR would skip loop emission and
directly generate `LoadInput` + `KernelCall`.

## Example 2 – Axis reduction (`golden/loop_fusion`)

SNAST excerpt (total payroll):

```
(Reduce :agg.sum over [employees]
  (InputRef departments.dept.employees.emp.salary) :: [departments, employees] -> integer
) :: [departments] -> integer
```

DF mapping:

- `df.input("departments.dept.employees.emp.salary")` with axes `[departments, employees]`.
- `df.reduce` node with:
  - `function=:agg.sum`
  - `axes=[departments]` (result axes)
  - `over_axes=[employees]`
  - `source_axis_plan` referencing the input plan for `departments`.

When lowering to Loop IR, the reducer metadata opens the `[departments]`
context, then emits an `employees` loop inside, declares an accumulator, and
calls `Accumulate` with `core.add`.

## Example 3 – Predicate + select (`golden/loop_fusion`, manager count)

```
(Reduce :agg.sum over [employees]
  (Select
    (Call :core.eq
      (InputRef ...role) :: [departments, employees] -> string
      (Const "manager") :: [] -> string
    ) :: [departments, employees] -> boolean
    (Const 1) :: [] -> integer
    (Const 0) :: [] -> integer
  ) :: [departments, employees] -> integer
) :: [departments] -> integer
```

DF nodes:

1. `df.input_role` (`axes=[departments, employees]`, `dtype=string`).
2. `df.constant("manager")`.
3. `df.map` (eq) producing boolean mask.
4. `df.select` with axes `[departments, employees]`, referencing the mask and the
   two scalar constants.
5. `df.reduce` (sum) over `[employees]`.

This chain shows DF can represent elementwise control flow (`select`) before
loops exist. Loop IR lowering would hoist constants, emit predicate evaluation
inside the employees loop, and accumulate 1/0 values.

## Example 4 – Hash/object assembly (`golden/loop_fusion`, department summary)

```
(Hash
  (Pair name (InputRef departments.dept.name))
  (Pair total_payroll (Ref total_payroll))
  (Pair manager_count (Ref manager_count))
) :: [departments] -> hash
```

DF perspective:

- `df.input_name` supplies the `name` field (`axes=[departments]`).
- `df.decl_ref(:total_payroll)` and `df.decl_ref(:manager_count)` provide the
  other values, already on `[departments]`.
- `df.make_object` node collects the three values and tags each attribute key.

Lowering uses the existing Loop IR `MakeObject` instruction, but DF clarifies
that object assembly is elementwise over `[departments]` and depends on other
DF declarations.

## Building These Examples in Specs

Use the helpers from `Kumi::IR::Testing::SnastFactory` and `IRHelpers`:

```ruby
snast = build_snast_module(:manager_count, axes: %i[departments], dtype: :integer) do
  salaries = ir_types.array(ir_types.scalar(:integer))
  snast_factory.reduce(
    fn: :\"agg.sum\",
    over: [:employees],
    axes: %i[departments],
    dtype: ir_types.scalar(:integer),
    arg: snast_factory.input_ref(
      path: %i[departments dept employees emp salary],
      axes: %i[departments employees],
      dtype: salaries
    )
  )
end
graph = Kumi::IR::DF::Graph.from_snast(snast)
```

Extend this pattern to mirror other golden SNAST fixtures; each declaration in
those files should translate into a DF subgraph following the mappings above.
