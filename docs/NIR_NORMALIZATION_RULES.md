# NAST Normalization Rules

## Core Invariant
**Every AST node becomes exactly one of: `Const`, `InputRef`, `Ref`, `Call`**

## Node Mapping Rules

### Literals → Const
```ruby
Kumi::Syntax::Literal(value: x) → NAST::Const(value: x)
```
- Numbers: `42` → `(Const 42)`
- Strings: `"hello"` → `(Const "hello")` 
- Booleans: `true` → `(Const true)`

### Input References → InputRef
```ruby
Kumi::Syntax::InputReference(name: :x) → NAST::InputRef(path: [:x])
Kumi::Syntax::InputElementReference(path: [:items, :price]) → NAST::InputRef(path: [:items, :price])
```
- Simple: `input.x` → `(InputRef [:x])`
- Nested: `input.items.price` → `(InputRef [:items, :price])`

### Declaration References → Ref
```ruby
Kumi::Syntax::DeclarationReference(name: :total) → NAST::Ref(name: :total)
```
- Trait refs: `high_performer` → `(Ref high_performer)`
- Value refs: `subtotal` → `(Ref subtotal)`

### Function Calls → Call (with Canonical Names)
```ruby
Kumi::Syntax::CallExpression(fn_name: :multiply, args: [a, b]) → NAST::Call(fn: :'core.mul', args: [norm(a), norm(b)])
```
- **Canonical normalization**: `:multiply` → `:'core.mul'`, `:>=` → `:'core.gte'`
- **Domain separation**: `core.*` (elementwise), `agg.*` (reductions)  
- **Cascade sugar**: `:cascade_and` → `:'core.and'`, `:if` → `:'core.select'`
- Operators: `x * y` → `(Call :"core.mul" (InputRef [:x]) (InputRef [:y]))`
- Functions: `sum(items.price)` → `(Call :"agg.sum" (InputRef [:items, :price]))`
- Comparisons: `x >= 5` → `(Call :"core.gte" (InputRef [:x]) (Const 5))`

### Cascades → Nested Select Calls
```ruby
CascadeExpression([case1, case2, base]) → 
  Call(:'core.select', [cond1, val1, 
    Call(:'core.select', [cond2, val2, base_val])])
```

**Algorithm:**
1. Find base case (condition = `true`)
2. Collect non-base cases 
3. Right-fold into nested `if` calls (reverse order)

**Example:**
```
value :status do
  on high_performer, "bonus"
  on active, "standard"  
  base "none"
end
```

Becomes:
```
(Call :"core.select"
  (Call :"core.and" (Ref high_performer))
  (Const "bonus")
  (Call :"core.select"
    (Call :"core.and" (Ref active))
    (Const "standard")
    (Const "none")))
```

## Location Preservation
**Every NAST node carries original `loc` for error reporting**
- `NAST::Node.new(..., loc: ast_node.loc)`
- Location preserved through all transformations for precise error messages
- Self-contained - no fragile references to original AST nodes
- Serializable and persistent across process boundaries

## Error Handling
**Unknown AST nodes become `Const(nil)` + error**
```ruby
else
  add_error(errors, node&.loc, "Unsupported AST node: #{node&.class}")
  NAST::Const.new(value: nil, loc: node&.loc)
```

## What NAST Does NOT Do
- ❌ No type inference
- ❌ No scope analysis  
- ❌ No broadcasting logic
- ❌ No function resolution
- ❌ No optimization
- ✅ **Pure syntax normalization only**