# Type Inference

Infers types from expressions and propagates them through dependency chains for compile-time type checking.

## Type Inference Rules

**Literals:**
- `42` → `:integer`
- `3.14` → `:float` 
- `"hello"` → `:string`
- `true` → `:boolean`
- `[1, 2, 3]` → `{ array: :integer }`

**Operations:**
- Integer arithmetic → `:integer`
- Mixed numeric operations → `:numeric`
- Comparisons → `:boolean`

**Functions:**
- Return types defined in function registry
- Arguments validated against parameter types

## Error Detection

**Type mismatches:**
```
TypeError: argument 2 of addition expects numeric, got input field `age` of declared type integer,
but argument 1 is input field `customer_name` of declared type string
```

**Function validation:**
- Arity validation (correct number of arguments)
- Type compatibility validation
- Unknown function detection

## Inference Process

- Processes declarations in topological order to resolve dependencies
- Literal types determined from values
- Function return types from function registry
- Array types unified from element types
- Cascade types inferred from result expressions