# Function Signature Analysis Integration

This document describes how NEP-20 function signatures integrate with Kumi's multi-pass analyzer architecture.

## Architecture Overview

Function signature resolution is integrated into the analyzer pipeline through a node index system that allows passes to share metadata efficiently.

```
┌─────────────────┐    ┌──────────────────────┐    ┌────────────────────┐
│   Toposorter    │───▶│ FunctionSignaturePass │───▶│   LowerToIRPass    │
│ Creates node    │    │ Resolves signatures   │    │ Validates metadata │
│ index by ID     │    │ Attaches metadata     │    │ Emits IR ops       │
└─────────────────┘    └──────────────────────┘    └────────────────────┘
```

## Node Index System

### Creation (Toposorter)

The `Toposorter` pass creates a comprehensive index of all nodes in the AST:

```ruby
# State structure after Toposorter
state[:node_index] = {
  object_id_1 => {
    node: CallExpression_instance,
    type: "CallExpression",
    metadata: {}
  },
  # ... more nodes
}
```

### Population (FunctionSignaturePass)

The `FunctionSignaturePass` populates metadata for `CallExpression` nodes:

```ruby
# After FunctionSignaturePass
entry[:metadata] = {
  signature: Signature_object,           # Full signature object
  result_axes: [:i, :j],                # Output dimension names  
  join_policy: :zip,                    # Cross-dimensional policy
  dropped_axes: [:k],                   # Dimensions eliminated by reductions
  effective_signature: {                # Normalized for lowering
    in_shapes: [[:i, :k], [:k, :j]],
    out_shape: [:i, :j], 
    join_policy: :zip
  },
  dim_env: { i: :i, j: :j, k: :k },    # Dimension variable bindings
  shape_contract: {                     # Simplified for lowering
    in: [[:i, :k], [:k, :j]],
    out: [:i, :j],
    join: :zip
  },
  signature_score: 0                    # Match quality (0 = exact)
}
```

### Consumption (LowerToIRPass)

The lowering pass validates and uses the signature metadata:

```ruby
def validate_signature_metadata(expr, entry)
  node_index = get_state(:node_index)
  metadata = node_index[expr.object_id][:metadata]
  
  # Validate dropped axes for reductions
  if entry&.reducer && metadata[:dropped_axes]
    # Assert axis exists in scope
  end
  
  # Warn about join policies not yet implemented
  if metadata[:join_policy]
    # Log warning or feature flag check
  end
end
```

## Pass Integration Points

### 1. Signature Resolution

**Location**: After `BroadcastDetector`, before `TypeChecker`

**Purpose**: Resolve NEP-20 signatures for all function calls

**Input**: 
- Node index from Toposorter
- Broadcast metadata (optional)
- Current function registry

**Output**: Rich signature metadata attached to call nodes

### 2. Type Checking Enhancement

**Integration**: `TypeChecker` can now use signature metadata for enhanced validation:

```ruby
def validate_function_call(node, errors)
  # Get resolved signature metadata
  node_entry = node_index[node.object_id]
  if node_entry && node_entry[:metadata][:signature]
    # Use NEP-20 signature for validation
    validate_nep20_signature(node, node_entry[:metadata], errors)
  else
    # Fall back to legacy registry-based validation
    validate_legacy_signature(node, errors)
  end
end
```

### 3. Lowering Integration

**Integration**: `LowerToIRPass` validates signature consistency and emits appropriate IR:

```ruby  
when Syntax::CallExpression
  entry = Kumi::Registry.entry(expr.fn_name)
  validate_signature_metadata(expr, entry)  # Read-only validation
  
  # Use shape contract for IR generation
  if node_entry = node_index[expr.object_id]
    contract = node_entry[:metadata][:shape_contract]
    # Use contract to emit appropriate reduce/join ops
  end
```

## Metadata Contract

All passes can rely on this metadata structure for `CallExpression` nodes:

| Field | Type | Description |
|-------|------|-------------|
| `:signature` | `Signature` | Full signature object with dimensions |
| `:result_axes` | `Array<Symbol>` | Output dimension names |
| `:join_policy` | `Symbol?` | `:zip`, `:product`, or `nil` |
| `:dropped_axes` | `Array<Symbol>` | Dimensions eliminated (reductions) |
| `:effective_signature` | `Hash` | Normalized signature for lowering |
| `:dim_env` | `Hash` | Dimension variable bindings |
| `:shape_contract` | `Hash` | Simplified contract for IR generation |
| `:signature_score` | `Integer` | Match quality (0 = exact) |

## Error Handling

Enhanced error messages include signature information:

```ruby
# Before
"operator `multiply` expects 2 args, got 3"

# After  
"Signature mismatch for `multiply` with args (i,j), (k). 
 Candidates: (),()->() | (i),(i)->(i). 
 no matching signature for shapes (i,j), (k)"
```

## Feature Flags

Control NEP-20 behavior at runtime:

```bash
export KUMI_ENABLE_FLEX=1    # Enable flexible dimension matching (?)
export KUMI_ENABLE_BCAST1=1  # Enable broadcastable matching (|1)  
```

## Future Extensions

The node index architecture supports future enhancements:

### Registry V2 Integration
```ruby
# Read signatures from YAML registry
signatures = RegistryV2.get_function_signatures(node.fn_name)
```

### Type System Integration
```ruby
# Add dtype metadata alongside shape metadata
metadata[:result_dtype] = infer_result_dtype(args, signature)
```

### Optimization Metadata
```ruby
# Add optimization hints
metadata[:can_vectorize] = true
metadata[:memory_access_pattern] = :sequential
```

## Performance Considerations

- **Node index creation**: O(n) where n = total AST nodes
- **Signature resolution**: O(k*m) where k = signatures, m = arguments  
- **Memory overhead**: ~100 bytes per CallExpression node
- **Pass integration**: Zero performance impact on existing passes

The architecture is designed for extensibility while maintaining backward compatibility with the existing analyzer pipeline.