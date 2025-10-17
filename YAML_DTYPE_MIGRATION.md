# YAML Dtype Format Migration Guide

## Overview

The dtype specification format in function YAML files has been upgraded from string-based to structured format. The system now supports **both formats simultaneously**, enabling gradual migration.

## Why Migrate?

- **Type-safe**: Structured format validates schema at load time
- **Self-documenting**: Structure shows required parameters explicitly
- **No parsing**: Eliminates regex overhead
- **Better errors**: Missing parameters caught immediately with clear messages
- **Future-proof**: Enables optimization like dispatch table pre-computation

## Format Comparison

### Legacy String Format

```yaml
functions:
  - id: core.add
    dtype: "promote(left_operand,right_operand)"

  - id: core.div
    dtype: "float"

  - id: agg.min
    dtype: "element_of(source_value)"
```

**Pros:** Compact
**Cons:** Requires regex parsing, error messages unclear

### New Structured Format

```yaml
functions:
  - id: core.add
    dtype:
      rule: promote
      params: [left_operand, right_operand]

  - id: core.div
    dtype:
      rule: scalar
      kind: float

  - id: agg.min
    dtype:
      rule: element_of
      param: source_value
```

**Pros:** Explicit, validated, self-documenting
**Cons:** Slightly more lines (but clearer intent)

## Structured Dtype Rules

### 1. `same_as` - Copy parameter's type

**When to use:** Output type matches input

```yaml
dtype:
  rule: same_as
  param: source_value
```

**Parameters:**
- `param` (required): Name of parameter whose type to use

**Example functions:** abs, clamp, identity operations

---

### 2. `promote` - Numeric type promotion

**When to use:** Multiple numeric inputs; output is promoted type

```yaml
dtype:
  rule: promote
  params: [left_operand, right_operand]
```

**Parameters:**
- `params` (required): Array of parameter names to promote
- Priority: float > integer > boolean

**Example functions:** add, multiply, power (binary arithmetic)

---

### 3. `element_of` - Extract element type

**When to use:** Reduction function; output is element type

```yaml
dtype:
  rule: element_of
  param: source_value
```

**Parameters:**
- `param` (required): Name of collection parameter

**Behavior:**
- ArrayType → element_type
- TupleType → promoted element types
- ScalarType → unchanged

**Example functions:** min, max, first (reductions)

---

### 4. `scalar` - Constant type

**When to use:** Fixed output type regardless of input

```yaml
dtype:
  rule: scalar
  kind: float
```

**Parameters:**
- `kind` (required): One of `:integer`, `:float`, `:string`, `:boolean`, `:hash`, `:any`, `:symbol`

**Example functions:** count (always integer), mean (always float)

---

### 5. `unify` - Unify two types

**When to use:** Two inputs that must have compatible types

```yaml
dtype:
  rule: unify
  param1: left
  param2: right
```

**Parameters:**
- `param1` (required): First parameter name
- `param2` (required): Second parameter name

**Behavior:** Promotes both to common type

**Example functions:** comparison operators (where both sides must unify)

---

### 6. `common_type` - Common type among elements

**When to use:** Array elements that must unify

```yaml
dtype:
  rule: common_type
  param: elements
```

**Parameters:**
- `param` (required): Parameter holding array of types

**Behavior:** Promotes all element types

**Example functions:** array construction, variadic functions

---

### 7. `array` - Array of element type

**When to use:** Output is array with specific element type

```yaml
# Constant element type
dtype:
  rule: array
  element_type: integer

# Parametric element type
dtype:
  rule: array
  element_type_param: elem_type
```

**Parameters:**
- `element_type` OR `element_type_param` (one required)
  - `element_type`: scalar kind (e.g., `:integer`, `:float`, `:string`)
  - `element_type_param`: parameter name holding the type

**Nested arrays:**
```yaml
dtype:
  rule: array
  element_type:
    rule: array
    element_type: string
```

---

### 8. `tuple` - Tuple of types

**When to use:** Output is tuple with specific element types

```yaml
# Constant types
dtype:
  rule: tuple
  element_types: [integer, float, string]

# From parameter (parameter holds array of types)
dtype:
  rule: tuple
  element_types_param: types
```

**Parameters:**
- `element_types` OR `element_types_param` (one required)
  - `element_types`: array of scalar kinds
  - `element_types_param`: parameter name holding array of types

---

## Migration Examples

### Example 1: Simple Scalar

**Before:**
```yaml
- id: core.div
  dtype: "float"
```

**After:**
```yaml
- id: core.div
  dtype:
    rule: scalar
    kind: float
```

---

### Example 2: Type Promotion

**Before:**
```yaml
- id: core.add
  params: [{ name: left_operand }, { name: right_operand }]
  dtype: "promote(left_operand,right_operand)"
```

**After:**
```yaml
- id: core.add
  params: [{ name: left_operand }, { name: right_operand }]
  dtype:
    rule: promote
    params: [left_operand, right_operand]
```

---

### Example 3: Element Type Extraction

**Before:**
```yaml
- id: agg.min
  params: [{ name: source_value }]
  dtype: "element_of(source_value)"
```

**After:**
```yaml
- id: agg.min
  params: [{ name: source_value }]
  dtype:
    rule: element_of
    param: source_value
```

---

### Example 4: Array Construction

**Before (hypothetical):**
```yaml
- id: make_array
  dtype: "array(integer)"
```

**After:**
```yaml
- id: make_array
  dtype:
    rule: array
    element_type: integer
```

---

## Migration Strategy

### Phase 1: Validation (Already Complete)
✅ Created `Loader.build_dtype_rule_from_yaml()`
✅ Handles both string and structured formats
✅ All tests pass
✅ Backward compatible with existing YAML

### Phase 2: Gradual Migration
Recommended approach: One dtype category at a time

1. **core/arithmetic.yaml** (4 functions with 3 unique patterns)
2. **core/comparison.yaml** (boolean functions)
3. **agg/numeric.yaml** (aggregate functions)
4. **core/select.yaml** (conditional function)
5. **core/boolean.yaml** (boolean operations)
6. **core/string.yaml** (string functions)
7. **agg/string.yaml** (string aggregations)
8. **agg/boolean.yaml** (boolean aggregations)
9. **core/constructor.yaml** (constructors)
10. **core/stencil.yaml** (spatial operations)

### Phase 3: Verification
- Run golden tests after each file (catch regressions early)
- No functional changes needed (loader handles compatibility)

### Phase 4: Cleanup
- Once all files migrated, remove `compile_dtype_rule` from hotpath
- Keep for backward compat in legacy projects if needed

## Error Messages (Validation)

The loader provides clear error messages when structured dtype is malformed:

```
Error: dtype hash requires 'rule' key
Error: same_as rule requires 'param' key
Error: promote rule requires 'params' key
Error: scalar rule requires 'kind' key
Error: scalar rule has unknown kind: invalid_type
Error: unknown dtype rule: foo
```

## Implementation Details

**Location:** `lib/kumi/registry_v2/loader.rb`
- `build_dtype_rule_from_yaml(dtype_spec)` - Main dispatcher
- `build_dtype_rule_from_hash(spec)` - Structured format handler

**Tests:** `spec/kumi/registry_v2/yaml_dtype_loader_spec.rb`
- 19 comprehensive tests covering:
  - Each rule type (8 rules)
  - Legacy string format (3 examples)
  - Error validation (5 error cases)
  - Nested structures (1 example)
  - Backward compatibility (1 integration test)

## Benefits Summary

| Aspect | Legacy | Structured |
|--------|--------|-----------|
| Parsing | Regex needed | No parsing |
| Validation | At compile time | At load time |
| Error messages | Unclear | Specific |
| Self-documenting | No | Yes |
| Type-safe | No | Yes |
| Testability | Hard | Easy |
| Performance | Slower | Faster |

## Timeline

- **Now:** Both formats work simultaneously
- **End of sprint 1:** All YAML files migrated
- **Post-migration:** Legacy format deprecated (optional)

## Questions?

- Refer to test cases in `yaml_dtype_loader_spec.rb` for examples
- Check PLAN.md for type system context
- See `TypeRules` builder methods for implementation details
