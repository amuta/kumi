# Output Schema

## Overview

The analyzer extracts metadata from output declarations (traits and values) into a minimal JSON schema.

## Access

```ruby
result = Kumi::Analyzer.analyze!(schema, side_tables: true)
output_schema = result.state[:output_schema]
```

```bash
bin/kumi analyze schema.kumi --dump output_schema --side-tables
```

## Schema Structure

```json
{
  "output_name": {
    "kind": "trait|value",
    "type": "string|integer|float|boolean",
    "axes": ["dimension1", "dimension2"]
  }
}
```

## Example

**Schema:**
```kumi
input items: array {
  item: hash {
    price: float
    quantity: integer
  }
}

trait expensive: items.item.price > 100.0
value total: items.item.price * items.item.quantity
```

**Generated Output Schema:**
```json
{
  "expensive": {
    "kind": "trait",
    "type": "boolean",
    "axes": ["items"]
  },
  "total": {
    "kind": "value",
    "type": "float",
    "axes": ["items"]
  }
}
```

## Fields

- **kind**: Declaration type (`trait` for boolean conditions, `value` for computed values)
- **type**: Result data type
- **axes**: Dimensional context (which input arrays this output iterates over)

## Implementation

The `OutputSchemaPass` runs after `SNASTPass` in the analyzer pipeline and extracts metadata from the Semantic NAST representation.
