# Function Signatures (NEP 20)

Kumi implements **NEP 20 conformant function signatures** for describing generalized universal functions. This system provides precise control over multidimensional operations with support for fixed-size, flexible, and broadcastable dimensions.

## Basic Syntax

Function signatures use the format: `<inputs> -> <outputs>[@policy]`

```ruby
"(i),(i)->(i)"           # Element-wise operation on vectors
"(m,n),(n,p)->(m,p)"     # Matrix multiplication  
"(i,j)->(i)"             # Reduction along j axis
"(),()->()"              # Scalar operation
```

## NEP 20 Extensions

### Fixed-Size Dimensions

Use integers to specify exact dimension sizes:

```ruby
"(3),(3)->(3)"          # Cross product for 3-vectors
"()->(2)"               # Function returning 2D vector
"(),()->(3)"            # Two scalars to 3D vector
```

Fixed-size dimensions must match exactly - no broadcasting allowed.

### Flexible Dimensions (?)

The `?` modifier indicates dimensions that can be omitted if not present in all operands:

```ruby
"(m?,n),(n,p?)->(m?,p?)" # matmul signature - handles:
                         # - (m,n),(n,p) -> (m,p)   matrix * matrix
                         # - (n),(n,p) -> (p)       vector * matrix  
                         # - (m,n),(n) -> (m)       matrix * vector
                         # - (n),(n) -> ()          vector * vector
```

### Broadcastable Dimensions (|1)

The `|1` modifier allows dimensions to broadcast against scalar or size-1 dimensions:

```ruby
"(n|1),(n|1)->()"       # all_equal - compares vectors or scalars
"(i|1),(j|1)->(i,j)"    # Outer product with broadcasting
```

**Constraints:**
- Only input dimensions can be broadcastable
- Output dimensions cannot have `|1` modifier
- Cannot combine `?` and `|1` on same dimension

## Join Policies

Control how different dimension names are combined:

### Default (nil policy)
All non-scalar arguments must have compatible dimension names:
```ruby
"(i),(i)->(i)"     # ✓ Compatible - same dimensions
"(i),(j)->(i,j)"   # ✗ Incompatible without policy
```

### @product Policy
Allows different dimensions, creates Cartesian product:
```ruby
"(i),(j)->(i,j)@product"  # Outer product
```

### @zip Policy  
Allows different dimensions, pairs them up:
```ruby
"(i),(j)->(i)@zip"        # Paired operation
```

## Examples from NEP 20

| Signature | Use Case | Description |
|-----------|----------|-------------|
| `(),()->()` | Addition | Scalar operations |
| `(i)->()` | Sum | Reduction over last axis |
| `(i\|1),(i\|1)->()` | all_equal | Equality test with broadcasting |
| `(i),(i)->()` | dot product | Inner vector product |
| `(m,n),(n,p)->(m,p)` | matmul | Matrix multiplication |
| `(3),(3)->(3)` | cross | Cross product for 3-vectors |
| `(m?,n),(n,p?)->(m?,p?)` | matmul | Universal matrix operations |

## Signature Validation Rules

1. **Arity matching**: Number of arguments must match signature
2. **Fixed-size consistency**: Integer dimensions must match exactly
3. **Broadcasting rules**: `|1` dimensions can broadcast to any size
4. **Flexible resolution**: `?` dimensions resolved based on presence
5. **Output constraints**: No broadcastable (`|1`) dimensions in outputs
6. **Policy requirements**: Different dimension names need explicit policy

## Matching Priority

When multiple signatures are available, resolution prefers:

1. **Exact matches** (score: 0) - All dimensions match perfectly
2. **Fixed-size matches** (score: 0-2) - Integer dimensions match
3. **Broadcast matches** (score: 1-3) - Scalar broadcasting  
4. **Flexible matches** (score: 10+) - Dimension omission/addition

Lower scores indicate better matches.

## Implementation Notes

Signatures are parsed into `Dimension` objects that track:
- Name (Symbol or Integer)
- Flexible flag (`?`)
- Broadcastable flag (`|1`)

The resolver handles NEP 20 semantics including:
- Flexible dimension resolution
- Broadcastable matching
- Fixed-size validation
- Join policy enforcement

## Limitations

Current implementation pending:
- Complex multi-dimensional join logic for operations like `(m,n),(n,p)->(m,p)` with nil policy
- Full flexible dimension resolution algorithm
- Advanced broadcasting patterns

For more details see [NEP 20 specification](https://numpy.org/neps/nep-0020-expansion-of-generalized-ufunc-signatures.html).