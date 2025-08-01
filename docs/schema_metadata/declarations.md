# Declarations Metadata

Processed declaration metadata for all schema declarations (traits and values) with clean, serializable information.

## Access

```ruby
metadata = MySchema.schema_metadata
declarations = metadata.declarations
```

## Structure

```ruby
# Returns Hash<Symbol, Hash>
{
  declaration_name => {
    type: :trait | :value,  # Declaration type
    expression: String      # Human-readable expression
  }
}
```

## Example

```ruby
metadata.declarations
# => {
#   :adult => { type: :trait, expression: ">=(input.age, 18)" },
#   :tax_amount => { type: :value, expression: "multiply(input.income, tax_rate)" },
#   :status => { type: :value, expression: "cascade" }
# }
```

## Raw AST Access

For advanced use cases requiring direct AST manipulation:

```ruby
raw_declarations = metadata.analyzer_state[:declarations]
# => { :adult => #<TraitDeclaration...>, :tax_amount => #<ValueDeclaration...> }
```

## AST Node Types

- **TraitDeclaration**: Boolean conditions  
- **ValueDeclaration**: Computed values or cascades

## Usage

- Dependency analysis
- Code generation  
- AST traversal
- Type inference