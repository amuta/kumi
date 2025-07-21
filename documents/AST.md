# Kumi AST Reference

## Core Node Types

**Root**: Schema container
```ruby
Root = Struct.new(:inputs, :attributes, :traits)
```

**FieldDecl**: Input field metadata  
```ruby
FieldDecl = Struct.new(:name, :domain, :type)
# DSL: integer :age, domain: 18..65 → FieldDecl(:age, 18..65, :integer)
```

**Trait**: Boolean predicate
```ruby  
Trait = Struct.new(:name, :expression)
# DSL: trait :adult, (input.age >= 18) → Trait(:adult, CallExpression(...))
```

**Attribute**: Computed value
```ruby
Attribute = Struct.new(:name, :expression)  
# DSL: value :total, fn(:add, a, b) → Attribute(:total, CallExpression(:add, [...]))
```

## Expression Nodes

**CallExpression**: Function calls and operators
```ruby
CallExpression = Struct.new(:fn_name, :args)
def &(other) = CallExpression.new(:and, [self, other])  # Enable chaining
```

**FieldRef**: Field access (`input.field_name`)
```ruby
FieldRef = Struct.new(:name)
# Has operator methods: >=, <=, >, <, ==, != that create CallExpression nodes
```

**Binding**: References to other declarations
```ruby
Binding = Struct.new(:name)
# Created by: ref(:name) OR bare identifier (trait_name) in composite traits
# DSL: ref(:adult) → Binding(:adult)
# DSL: adult & verified → CallExpression(:and, [Binding(:adult), Binding(:verified)])
```

**Literal**: Constants (`18`, `"text"`, `true`) 
```ruby
Literal = Struct.new(:value)
```

**ListExpression**: Arrays (`[1, 2, 3]`)
```ruby
ListExpression = Struct.new(:elements)
```

## Cascade Expressions (Conditional Values)

**CascadeExpression**: Container for conditional logic
```ruby
CascadeExpression = Struct.new(:cases)
```

**WhenCaseExpression**: Individual conditions
```ruby
WhenCaseExpression = Struct.new(:condition, :result)
```

**Case type mappings**:
- `on :a, :b, result` → `condition: fn(:all?, ref(:a), ref(:b))`  
- `on_any :a, :b, result` → `condition: fn(:any?, ref(:a), ref(:b))`
- `base result` → `condition: literal(true)`

## Key Nuances

**Operator methods on FieldRef**: Enable `input.age >= 18` syntax by defining operators that create `CallExpression` nodes

**CallExpression `&` method**: Enables expression chaining like `(expr1) & (expr2)`

**Node immutability**: AST nodes are frozen after construction; analysis results stored separately

**Location tracking**: All nodes include file/line/column for error reporting

**Tree traversal**: Each node defines `children` method for recursive processing

**Expression wrapping**: During parsing, raw values auto-convert to `Literal` nodes via `ensure_syntax()`

## Common Expression Trees

**Simple**: `(input.age >= 18)`
```
CallExpression(:>=, [FieldRef(:age), Literal(18)])
```

**Chained AND**: `(input.age >= 21) & (input.verified == true)`  
```
CallExpression(:and, [
  CallExpression(:>=, [FieldRef(:age), Literal(21)]),
  CallExpression(:==, [FieldRef(:verified), Literal(true)])
])
```

**Composite Trait**: `adult & verified & high_income`
```
CallExpression(:and, [
  CallExpression(:and, [
    Binding(:adult),
    Binding(:verified)
  ]),
  Binding(:high_income)
])
```

**Mixed Composition**: `adult & (input.score > 80) & verified`
```
CallExpression(:and, [
  CallExpression(:and, [
    Binding(:adult),
    CallExpression(:>, [FieldRef(:score), Literal(80)])
  ]),
  Binding(:verified)
])
```