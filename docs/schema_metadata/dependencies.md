# Dependencies Metadata

Processed dependency information showing relationships between declarations with clean, serializable data.

## Access

```ruby
metadata = MySchema.schema_metadata
dependencies = metadata.dependencies
```

## Structure

```ruby
# Returns Hash<Symbol, Array<Hash>>
{
  declaration_name => [
    {
      to: Symbol,           # Target declaration name
      conditional: Boolean, # True if dependency is conditional (cascade branch)
      cascade_owner: Symbol # Optional: cascade that owns this conditional edge
    }
  ]
}
```

## Example

```ruby
metadata.dependencies
# => {
#   :tax_amount => [
#     { to: :income, conditional: false },
#     { to: :deductions, conditional: false }
#   ],
#   :status => [
#     { to: :adult, conditional: true, cascade_owner: :status },
#     { to: :verified, conditional: true, cascade_owner: :status }
#   ]
# }
```

## Raw Edge Objects

For advanced use cases requiring direct Edge object access:

```ruby
raw_dependencies = metadata.analyzer_state[:dependencies]
# => { :tax_amount => [#<Edge to: :income>, #<Edge to: :deductions>] }
```

## Usage

- Topological sorting
- Cycle detection  
- Evaluation planning
- Dependency visualization