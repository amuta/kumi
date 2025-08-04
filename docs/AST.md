# Kumi AST Reference

## Core Node Types

**Root**: Schema container
```ruby
Root = Struct.new(:inputs, :attributes, :traits)
```

**InputDeclaration**: Input field metadata  
```ruby
InputDeclaration = Struct.new(:name, :domain, :type)
# DSL: integer :age, domain: 18..65 → InputDeclaration(:age, 18..65, :integer)
```

**TraitDeclaration**: Boolean predicate
```ruby  
TraitDeclaration = Struct.new(:name, :expression)
# DSL: trait :adult, (input.age >= 18) → TraitDeclaration(:adult, CallExpression(...))
```

**ValueDeclaration**: Computed value
```ruby
ValueDeclaration = Struct.new(:name, :expression)  
# DSL: value :total, fn(:add, a, b) → ValueDeclaration(:total, CallExpression(:add, [...]))
```

## Expression Nodes

**CallExpression**: Function calls and operators
```ruby
CallExpression = Struct.new(:fn_name, :args)
def &(other) = CallExpression.new(:and, [self, other])  # Enable chaining
```

**InputReference**: Field access (`input.field_name`)
```ruby
InputReference = Struct.new(:name)
# Has operator methods: >=, <=, >, <, ==, != that create CallExpression nodes
```

**InputElementReference**: Access of nested input fields (`input.field_name.element.subelement.subsubelement`)
```ruby
InputElementReference = Struct.new(:path)
# Represents nested input access
# DSL: input.address.street → InputElementReference([:address, :street])
```

**DeclarationReference**: References to other declarations
```ruby
DeclarationReference = Struct.new(:name)
# Created by: ref(:name) OR bare identifier (trait_name) in composite traits
# DSL: ref(:adult) → DeclarationReference(:adult)
# DSL: adult & verified → CallExpression(:and, [DeclarationReference(:adult), DeclarationReference(:verified)])
```

**Literal**: Constants (`18`, `"text"`, `true`) 
```ruby
Literal = Struct.new(:value)
```

**ArrayExpression**: Arrays (`[1, 2, 3]`)
```ruby
ArrayExpression = Struct.new(:elements)
```

## Cascade Expressions (Conditional Values)

**CascadeExpression**: Container for conditional logic
```ruby
CascadeExpression = Struct.new(:cases)
```

**CaseExpression**: Individual conditions
```ruby
CaseExpression = Struct.new(:condition, :result)
```

**Case type mappings**:
- `on :a, :b, result` → `condition: fn(:cascade_and, ref(:a), ref(:b))`  
- `on_any :a, :b, result` → `condition: fn(:any?, ref(:a), ref(:b))`
- `base result` → `condition: literal(true)`

## Key Nuances

**Operator methods on InputReference**: Enable `input.age >= 18` syntax by defining operators that create `CallExpression` nodes

**CallExpression `&` method**: Enables expression chaining like `(expr1) & (expr2)`

**Node immutability**: AST nodes are frozen after construction; analysis results stored separately

**Location tracking**: All nodes include file/line/column for error reporting

**Tree traversal**: Each node defines `children` method for recursive processing

**Expression wrapping**: During parsing, raw values auto-convert to `Literal` nodes via `ensure_syntax()`

## Common Expression Trees

**Simple**: `(input.age >= 18)`
```
CallExpression(:>=, [InputReference(:age), Literal(18)])
```

**Chained AND**: `(input.age >= 21) & (input.verified == true)`  
```
CallExpression(:and, [
  CallExpression(:>=, [InputReference(:age), Literal(21)]),
  CallExpression(:==, [InputReference(:verified), Literal(true)])
])
```

**Composite Trait**: `adult & verified & high_income`
```
CallExpression(:and, [
  CallExpression(:and, [
    DeclarationReference(:adult),
    DeclarationReference(:verified)
  ]),
  DeclarationReference(:high_income)
])
```

**Mixed Composition**: `adult & (input.score > 80) & verified`
```
CallExpression(:and, [
  CallExpression(:and, [
    DeclarationReference(:adult),
    CallExpression(:>, [InputReference(:score), Literal(80)])
  ]),
  DeclarationReference(:verified)
])
```