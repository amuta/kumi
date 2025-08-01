# Input Metadata

Raw input field metadata extracted from `input` blocks during analysis.

## Access

```ruby
metadata = MySchema.schema_metadata

# Processed input metadata (recommended for tools)
inputs = metadata.inputs

# Raw input metadata (advanced usage)
raw_inputs = metadata.analyzer_state[:inputs]
```

## Raw Structure

```ruby
# Raw analyzer state format
{
  field_name => {
    type: Symbol,           # :integer, :string, :float, :boolean, :array, etc. 
    domain: Range|Array,    # optional domain constraints
    children: Hash          # for array/hash types
  }
}
```

## Processed Structure

```ruby 
# Processed metadata format (via metadata.inputs)
{
  field_name => {
    type: Symbol,           # normalized type
    domain: Hash,           # normalized domain metadata
    required: Boolean       # always true currently
  }
}
```

## Examples

**Processed Input Metadata:**
```ruby
metadata.inputs
# => {
#   :age => { 
#     type: :integer, 
#     domain: { type: :range, min: 0, max: 120, exclusive_end: false },
#     required: true 
#   },
#   :name => { type: :string, required: true },
#   :active => { type: :boolean, required: true }
# }
```

**Raw Input Metadata:**
```ruby
metadata.analyzer_state[:inputs]
# => {
#   :age => { type: :integer, domain: 0..120 },
#   :name => { type: :string },
#   :line_items => {
#     type: :array,
#     children: {
#       :price => { type: :float, domain: 0..Float::INFINITY },
#       :quantity => { type: :integer, domain: 1..100 }
#     }
#   }
# }
```

**Domain Types:**
- Range: `18..65`, `0..Float::INFINITY`
- Array: `%w[active inactive suspended]`  
- Proc: Custom validation functions

## Usage

Form generators use this metadata to:
- Create appropriate input controls
- Set validation rules  
- Build nested forms for arrays
- Generate type-safe schemas