# Input Form Schema

## Overview

The analyzer generates a minimal JSON schema from input declarations for dynamic form building.

## Access

```ruby
result = Kumi::Analyzer.analyze!(schema)
form_schema = result.state[:input_form_schema]
```

```bash
bin/kumi analyze schema.kumi --dump input_form_schema
```

## Schema Structure

### Scalar Fields
```json
{
  "field_name": {
    "type": "string|integer|float|boolean"
  }
}
```

### Array Fields
```json
{
  "field_name": {
    "type": "array",
    "element": { /* recursive field structure */ }
  }
}
```

### Object Fields
```json
{
  "field_name": {
    "type": "object",
    "fields": {
      "nested_field": { /* recursive field structure */ }
    }
  }
}
```

## Example

**Schema:**
```kumi
input items: array {
  item: hash {
    name: string
    price: float
  }
}
input discount: float
```

**Generated Form Schema:**
```json
{
  "items": {
    "type": "array",
    "element": {
      "type": "object",
      "fields": {
        "name": { "type": "string" },
        "price": { "type": "float" }
      }
    }
  },
  "discount": {
    "type": "float"
  }
}
```

## Implementation

The `InputFormSchemaPass` runs after `InputCollector` in the analyzer pipeline and produces a clean schema containing only type information needed for form generation, excluding internal metadata like access modes and navigation steps.
