# Kumi DSL Reference

## Core Syntax

**Schema Structure**:
```ruby
schema do
  input do
    # Field declarations 
  end
  # Traits and values
end
```

## Input Fields

**Type-specific methods** (preferred):
```ruby
string :name
integer :age, domain: 18..65  
float :score, domain: 0.0..100.0
boolean :active
array :tags, elem: { type: :string }
hash :metadata, key: { type: :string }, val: { type: :any }
```

**Generic method**:
```ruby
key :field_name, type: :any, domain: constraint
```

**Domain constraints**: `Range` (1..100), `Array` (%w[a b c]), `Proc` (->(x) { x > 0 })

## Traits (Boolean Predicates)

**Current syntax**:
```ruby
trait :adult, (input.age >= 18)
trait :qualified, (input.age >= 21) & (input.score > 80) & (input.verified == true)
```

**Composite trait syntax** (NEW):
```ruby
# Base traits
trait :adult, (input.age >= 18)
trait :verified, (input.verified == true) 
trait :high_score, (input.score > 80)

# Composite traits using bare identifier syntax
trait :eligible, adult & verified & high_score
trait :mixed, adult & (input.income > 50_000) & verified
```

**Keyword syntax**:
```ruby  
trait adult: (input.age >= 18), qualified: (input.score > 80)
```

## Values (Computed Fields)

**Simple**:
```ruby
value :status, input.account_type
value :total_score, fn(:add, input.score1, input.score2)
```

**Conditional**:
```ruby
value :access_level do
  on :premium, :verified, "full_access"
  on_any :staff, :admin, "elevated" 
  on_none :blocked, :suspended, "active"
  base "basic"
end
```

## Expressions

**Field access**: `input.field_name` → `FieldRef` node with operator methods

**Comparisons**: `>=`, `<=`, `>`, `<`, `==`, `!=` create `CallExpression` nodes

**Logical AND**: `(expr1) & (expr2)` → `CallExpression(:and, [expr1, expr2])`

**Functions**: `fn(:name, arg1, arg2)` → `CallExpression(:name, [arg1, arg2])`

**References**: 
- `ref(:trait_name)` → `Binding` node (traditional)
- `trait_name` → `Binding` node (bare identifier, NEW)

**Literals**: `18`, `"text"`, `true`, `[1,2,3]` → `Literal` or `ListExpression` nodes

## Key Constraints

**AND-only logic**: No OR operations to maintain constraint satisfaction

**Input block required**: All schemas must declare expected fields

**Dependency resolution**: All references must be resolvable (no cycles)

**Type safety**: Declared field types checked against expression usage