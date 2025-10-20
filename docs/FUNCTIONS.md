# Kumi Function Reference

Auto-generated documentation for Kumi functions and their kernels.

## `__select__`

**Aliases:** `if`, `select`

- **Arity:** 3
- **Type:** same as `value_when_true`

### Parameters

- `condition_mask`
- `value_when_true`
- `value_when_false`

## `agg.all`

**Aliases:** `all`, `all?`

- **Arity:** 1
- **Type:** boolean
- **Behavior:** Reduces a dimension `[D] -> T`

### Parameters

- `source_value`

### Implementations

#### Ruby

`all:ruby:v1`

**Inline:** `= $0 && $1` (`$0` = accumulator, `$1` = element)

**Implementation:**

```ruby
(a, b)
  a && b
```

**Identity:**
- boolean: `true`

## `agg.any`

**Aliases:** `any`, `any?`

- **Arity:** 1
- **Type:** boolean
- **Behavior:** Reduces a dimension `[D] -> T`

### Parameters

- `source_value`

### Implementations

#### Ruby

`any:ruby:v1`

**Inline:** `= $0 || $1` (`$0` = accumulator, `$1` = element)

**Implementation:**

```ruby
(a, b)
  a || b
```

**Identity:**
- boolean: `false`

## `agg.count`

- **Arity:** 1
- **Type:** integer
- **Behavior:** Reduces a dimension `[D] -> T`

### Parameters

- `source_value`

### Implementations

#### Ruby

`agg.count:ruby:v1`

**Inline:** `+= 1` (`$0` = accumulator, `$1` = element)

**Implementation:**

```ruby
(a,_b)
  a + 1
```

**Fold:** `= $0.count`

**Identity:**
- any: `0`

**Reduction:** Monoid operation with identity element

## `agg.count_if`

- **Arity:** 2
- **Type:** integer
- **Behavior:** Reduces a dimension `[D] -> T`

### Parameters

- `condition`
- `source_value`

## `agg.join`

- **Arity:** 1
- **Type:** string
- **Behavior:** Reduces a dimension `[D] -> T`

### Parameters

- `source_value`

### Implementations

#### Ruby

`agg.join:ruby:v1`

**Fold:** `= $0.join`

_Note: No identity value. First element initializes accumulator._

**Reduction:** First element is initial value (no identity)

## `agg.max`

- **Arity:** 1
- **Type:** element of `source_value`
- **Behavior:** Reduces a dimension `[D] -> T`

### Parameters

- `source_value`

### Implementations

#### Ruby

`agg.max:ruby:v1`

**Implementation:**

```ruby
(a, b)
  a > b ? a : b
```

**Fold:** `= $0.max`

_Note: No identity value. First element initializes accumulator._

**Reduction:** First element is initial value (no identity)

## `agg.mean`

**Aliases:** `avg`, `mean`

- **Arity:** 1
- **Type:** float
- **Behavior:** Reduces a dimension `[D] -> T`

### Parameters

- `source_value`

## `agg.mean_if`

**Aliases:** `avg_if`, `mean_if`

- **Arity:** 2
- **Type:** float
- **Behavior:** Reduces a dimension `[D] -> T`

### Parameters

- `source_value`
- `condition`

## `agg.min`

- **Arity:** 1
- **Type:** element of `source_value`
- **Behavior:** Reduces a dimension `[D] -> T`

### Parameters

- `source_value`

### Implementations

#### Ruby

`agg.min:ruby:v1`

**Implementation:**

```ruby
(a, b)
  a < b ? a : b
```

**Fold:** `= $0.min`

_Note: No identity value. First element initializes accumulator._

**Reduction:** First element is initial value (no identity)

## `agg.sum`

- **Arity:** 1
- **Type:** same as `source_value`
- **Behavior:** Reduces a dimension `[D] -> T`

### Parameters

- `source_value`

### Implementations

#### Ruby

`agg.sum:ruby:v1`

**Inline:** `+= $1` (`$0` = accumulator, `$1` = element)

**Implementation:**

```ruby
(a,b)
  a + b
```

**Fold:** `= $0.sum`

**Identity:**
- float: `0.0`
- integer: `0`

**Reduction:** Monoid operation with identity element

## `agg.sum_if`

- **Arity:** 2
- **Type:** same as `source_value`
- **Behavior:** Reduces a dimension `[D] -> T`

### Parameters

- `source_value`
- `condition`

## `core.abs`

- **Arity:** 1
- **Type:** same as `number`

### Parameters

- `number`

### Implementations

#### Ruby

`abs:ruby:v1`

_Note: No identity value. First element initializes accumulator._

## `core.add`

- **Arity:** 2
- **Type:** promoted from `left_operand`, `right_operand`

### Parameters

- `left_operand`
- `right_operand`

### Implementations

#### Ruby

`add:ruby:v1`

**Implementation:**

```ruby
(a, b)
  a + b
```

_Note: No identity value. First element initializes accumulator._

## `core.and`

**Aliases:** `&`, `and`

- **Arity:** 2
- **Type:** boolean

### Parameters

- `left_operand`
- `right_operand`

### Implementations

#### Ruby

`and:ruby:v1`

**Implementation:**

```ruby
(a, b)
  a && b
```

_Note: No identity value. First element initializes accumulator._

## `core.array_size`

**Aliases:** `array_size`, `size`

- **Arity:** 1
- **Type:** integer

### Parameters

- `collection`

### Implementations

#### Ruby

`size:ruby:v1`

**Implementation:**

```ruby
(collection)
  collection.size
```

**Fold:** `= $0.length`

_Note: No identity value. First element initializes accumulator._

## `core.at`

**Aliases:** `[]`, `at`, `get`

- **Arity:** 2
- **Type:** element of `collection`

### Parameters

- `collection`
- `index`

### Implementations

#### Ruby

`at:ruby:v1`

_Note: No identity value. First element initializes accumulator._

## `core.clamp`

- **Arity:** 3
- **Type:** same as `x`

### Parameters

- `x`
- `lo`
- `hi`

### Implementations

#### Ruby

`clamp:ruby:v1`

**Implementation:**

```ruby
(x, lo, hi)
  [[x, lo].max, hi].min
```

_Note: No identity value. First element initializes accumulator._

## `core.concat`

- **Arity:** 2
- **Type:** string

### Parameters

- `left_string`
- `right_string`

### Implementations

#### Ruby

`concat:ruby:v1`

**Implementation:**

```ruby
(a, b)
a.to_s + b.to_s
```

_Note: No identity value. First element initializes accumulator._

## `core.div`

**Aliases:** `div`, `divide`

- **Arity:** 2
- **Type:** float

### Parameters

- `left_operand`
- `right_operand`

### Implementations

#### Ruby

`div:ruby:v1`

**Implementation:**

```ruby
(a, b)
  a / b.to_f
```

_Note: No identity value. First element initializes accumulator._

## `core.downcase`

- **Arity:** 1
- **Type:** string

### Parameters

- `string`

### Implementations

#### Ruby

`downcase:ruby:v1`

_Note: No identity value. First element initializes accumulator._

## `core.eq`

**Aliases:** `==`, `eq`, `equal`

- **Arity:** 2
- **Type:** boolean

### Parameters

- `left_operand`
- `right_operand`

### Implementations

#### Ruby

`eq:ruby:v1`

**Implementation:**

```ruby
(a, b)
  a == b
```

_Note: No identity value. First element initializes accumulator._

## `core.gt`

**Aliases:** `>`, `greater_than`, `gt`

- **Arity:** 2
- **Type:** boolean

### Parameters

- `left_operand`
- `right_operand`

### Implementations

#### Ruby

`gt:ruby:v1`

**Implementation:**

```ruby
(a, b)
  a > b
```

_Note: No identity value. First element initializes accumulator._

## `core.gte`

**Aliases:** `>=`, `ge`, `greater_than_or_equal`, `gte`

- **Arity:** 2
- **Type:** boolean

### Parameters

- `left_operand`
- `right_operand`

### Implementations

#### Ruby

`gte:ruby:v1`

**Implementation:**

```ruby
(a, b)
  a >= b
```

_Note: No identity value. First element initializes accumulator._

## `core.hash_fetch`

- **Arity:** 1
- **Type:** any

### Parameters

- `key`

## `core.length`

**Aliases:** `len`, `length`

- **Arity:** 1
- **Type:** integer

### Parameters

- `collection`

### Implementations

#### Ruby

`length:ruby:v1`

**Implementation:**

```ruby
(collection)
  collection.size
```

**Fold:** `= $0.length`

_Note: No identity value. First element initializes accumulator._

## `core.lt`

**Aliases:** `<`, `less_than`, `lt`

- **Arity:** 2
- **Type:** boolean

### Parameters

- `left_operand`
- `right_operand`

### Implementations

#### Ruby

`lt:ruby:v1`

**Implementation:**

```ruby
(a, b)
  a < b
```

_Note: No identity value. First element initializes accumulator._

## `core.lte`

**Aliases:** `<=`, `le`, `less_than_or_equal`, `lte`

- **Arity:** 2
- **Type:** boolean

### Parameters

- `left_operand`
- `right_operand`

### Implementations

#### Ruby

`lte:ruby:v1`

**Implementation:**

```ruby
(a, b)
  a <= b
```

_Note: No identity value. First element initializes accumulator._

## `core.mod`

**Aliases:** `%`, `mod`, `modulo`

- **Arity:** 2
- **Type:** promoted from `left_operand`, `right_operand`

### Parameters

- `left_operand`
- `right_operand`

### Implementations

#### V1

`mod.ruby:v1`

_Note: No identity value. First element initializes accumulator._

## `core.mul`

**Aliases:** `mul`, `multiply`

- **Arity:** 2
- **Type:** promoted from `left_operand`, `right_operand`

### Parameters

- `left_operand`
- `right_operand`

### Implementations

#### Ruby

`mul:ruby:v1`

**Implementation:**

```ruby
(a, b)
  a * b
```

_Note: No identity value. First element initializes accumulator._

## `core.neq`

**Aliases:** `!=`, `neq`, `not_equal`

- **Arity:** 2
- **Type:** boolean

### Parameters

- `left_operand`
- `right_operand`

### Implementations

#### Ruby

`neq:ruby:v1`

**Implementation:**

```ruby
(a, b)
  a != b
```

_Note: No identity value. First element initializes accumulator._

## `core.not`

**Aliases:** `!`, `not`

- **Arity:** 1
- **Type:** boolean

### Parameters

- `operand`

### Implementations

#### Ruby

`not:ruby:v1`

**Implementation:**

```ruby
(a)
  !a
```

_Note: No identity value. First element initializes accumulator._

## `core.or`

**Aliases:** `or`, `|`

- **Arity:** 2
- **Type:** boolean

### Parameters

- `left_operand`
- `right_operand`

### Implementations

#### Ruby

`or:ruby:v1`

**Implementation:**

```ruby
(a, b)
  a || b
```

_Note: No identity value. First element initializes accumulator._

## `core.pow`

**Aliases:** `pow`, `power`

- **Arity:** 2
- **Type:** promoted from `base`, `exponent`

### Parameters

- `base`
- `exponent`

### Implementations

#### Ruby

`pow:ruby:v1`

**Implementation:**

```ruby
(a, b)
  a ** b
```

_Note: No identity value. First element initializes accumulator._

## `core.sub`

**Aliases:** `sub`, `subtract`

- **Arity:** 2
- **Type:** promoted from `left_operand`, `right_operand`

### Parameters

- `left_operand`
- `right_operand`

### Implementations

#### Ruby

`sub:ruby:v1`

**Implementation:**

```ruby
(a, b)
  a - b
```

_Note: No identity value. First element initializes accumulator._

## `core.to_decimal`

- **Arity:** 1
- **Type:** decimal

### Parameters

- `value`

### Implementations

#### Ruby

`to_decimal:ruby:v1`

**Implementation:**

```ruby
(value)
  case value
  when BigDecimal then value
  when String then BigDecimal(value)
  when Numeric then BigDecimal(value.to_s)
  else raise TypeError, "Cannot coerce #{value.class} to Decimal"
  end
```

_Note: No identity value. First element initializes accumulator._

## `core.to_float`

- **Arity:** 1
- **Type:** float

### Parameters

- `value`

### Implementations

#### Ruby

`to_float:ruby:v1`

**Implementation:**

```ruby
(value)
  value.to_f
```

_Note: No identity value. First element initializes accumulator._

## `core.to_integer`

**Aliases:** `to_int`, `to_integer`

- **Arity:** 1
- **Type:** integer

### Parameters

- `value`

### Implementations

#### Ruby

`to_integer:ruby:v1`

**Implementation:**

```ruby
(value)
  value.to_i
```

_Note: No identity value. First element initializes accumulator._

## `core.to_string`

**Aliases:** `to_str`, `to_string`

- **Arity:** 1
- **Type:** string

### Parameters

- `value`

### Implementations

#### Ruby

`to_string:ruby:v1`

**Implementation:**

```ruby
(value)
  value.to_s
```

_Note: No identity value. First element initializes accumulator._

## `core.upcase`

- **Arity:** 1
- **Type:** string

### Parameters

- `string`

### Implementations

#### Ruby

`upcase:ruby:v1`

_Note: No identity value. First element initializes accumulator._
