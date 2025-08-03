# Schema Metadata

Kumi's SchemaMetadata interface accesses analyzed schema information for building external tools like form generators, documentation systems, and analysis utilities.

## Primary Interface

SchemaMetadata is the main interface for extracting metadata from Kumi schemas:

```ruby
metadata = MySchema.schema_metadata
```

See the API documentation in the SchemaMetadata class for method documentation, examples, and usage patterns.

## Processed Metadata (Tool-Friendly)

These methods return clean, serializable data structures:

| Method | Returns | Description |
|--------|---------|-------------|
| `inputs` | Hash | Input field metadata with normalized types and domains |
| `values` | Hash | Value declarations with dependencies and expressions |
| `traits` | Hash | Trait conditions with dependency information |
| `functions` | Hash | Function registry info for functions used in schema |
| `to_h` | Hash | Complete processed metadata (inputs, values, traits, functions) |
| `to_json` | String | JSON serialization of processed metadata |
| `to_json_schema` | Hash | JSON Schema document for input validation |

## Raw Analyzer State (Advanced)

Direct access to internal analyzer results:

| Method | Returns | Description |
|--------|---------|-------------|
| [`declarations`](schema_metadata/declarations.md) | Hash | Raw AST declaration nodes by name |
| [`dependencies`](schema_metadata/dependencies.md) | Hash | Dependency graph with Edge objects |
| `dependents` | Hash | Reverse dependency lookup |
| `leaves` | Hash | Leaf nodes (no dependencies) by type |
| [`evaluation_order`](schema_metadata/evaluation_order.md) | Array | Topologically sorted evaluation order |
| [`inferred_types`](schema_metadata/inferred_types.md) | Hash | Type inference results for declarations |
| [`cascades`](schema_metadata/cascades.md) | Hash | Cascade mutual exclusion analysis |
| [`broadcasts`](schema_metadata/broadcasts.md) | Hash | Array broadcasting operation metadata |
| `analyzer_state` | Hash | Complete raw analyzer state with AST nodes |

Note: Raw `inputs` metadata is available via `analyzer_state[:inputs]` but the processed `inputs` method is recommended for tool development.

## Usage Patterns

```ruby
# Tool development - use processed metadata
metadata = MySchema.schema_metadata
form_fields = metadata.inputs.map { |name, info| create_field(name, info) }
documentation = metadata.values.map { |name, info| document_value(name, info) }

# Advanced analysis - use raw state when needed  
dependency_graph = metadata.dependencies
ast_nodes = metadata.declarations
evaluation_sequence = metadata.evaluation_order
```

## Data Structure Examples

### Processed Input Metadata
```ruby
metadata.inputs
# => {
#   :age => { type: :integer, domain: { type: :range, min: 18, max: 65 }, required: true },
#   :name => { type: :string, required: true },
#   :items => { type: :array, required: true }
# }
```

### Processed Value Metadata
```ruby
metadata.values
# => {
#   :tax_amount => {
#     type: :float,
#     dependencies: [:income, :tax_rate],
#     computed: true,
#     expression: "multiply(input.income, tax_rate)"
#   }
# }
```

### Public Interface Examples
```ruby
# Processed dependency information
metadata.dependencies
# => { :tax_amount => [{ to: :income, conditional: false }, { to: :tax_rate, conditional: false }] }

# Processed declaration metadata
metadata.declarations  
# => { :adult => { type: :trait, expression: ">=(input.age, 18)" }, :tax_amount => { type: :value, expression: "multiply(input.income, tax_rate)" } }

# Type inference results
metadata.inferred_types
# => { :adult => :boolean, :tax_amount => :float, :item_totals => { array: :float } }
```

### Raw Analyzer State (Advanced Usage)
```ruby
# Raw state hash with internal objects (AST nodes, Edge objects)
metadata.analyzer_state
# => { declarations: {AST nodes...}, dependencies: {Edge objects...}, ... }
```

See `docs/schema_metadata/` for detailed examples.