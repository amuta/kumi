# Inferred Types Metadata

Type inference results for all declarations based on expression analysis.

## Access

```ruby
metadata = MySchema.schema_metadata
types = metadata.inferred_types
```

## Structure

```ruby
# Returns Hash<Symbol, Object>
{
  declaration_name => type_specification
}
```

## Example

```ruby
metadata.inferred_types
# => {
#   :adult => :boolean,
#   :age_group => :string, 
#   :tax_rate => :float,
#   :count => :integer,
#   :item_prices => { array: :float },
#   :categories => { array: :string }
# }
```

## Type Values

- `:boolean`, `:string`, `:integer`, `:float`, `:any`
- `{ array: element_type }` for arrays
- `{ hash: { key: key_type, value: value_type } }` for hashes

## Usage

- Type checking
- Code generation
- Editor support
- Runtime validation