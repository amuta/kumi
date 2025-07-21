# Kumi Standard Function Library Reference

Kumi provides a rich library of built-in functions for use within `value` and `trait` expressions via `fn(...)`.

## Logical Functions

* **`all?`**: Check if all elements in collection are truthy
  * **Usage**: `fn(:all?, array(any) arg1)` → `boolean`
* **`and`**: Logical AND of multiple conditions
  * **Usage**: `fn(:and, boolean1, boolean2, ...)` → `boolean`
* **`any?`**: Check if any element in collection is truthy
  * **Usage**: `fn(:any?, array(any) arg1)` → `boolean`
* **`none?`**: Check if no elements in collection are truthy
  * **Usage**: `fn(:none?, array(any) arg1)` → `boolean`
* **`not`**: Logical NOT
  * **Usage**: `fn(:not, boolean arg1)` → `boolean`
* **`or`**: Logical OR of multiple conditions
  * **Usage**: `fn(:or, boolean1, boolean2, ...)` → `boolean`

## Comparison Functions

* **`!=`**: Inequality comparison
  * **Usage**: `fn(:!=, any arg1, any arg2)` → `boolean`
* **`<`**: Less than comparison
  * **Usage**: `fn(:<, float arg1, float arg2)` → `boolean`
* **`<=`**: Less than or equal comparison
  * **Usage**: `fn(:<=, float arg1, float arg2)` → `boolean`
* **`==`**: Equality comparison
  * **Usage**: `fn(:==, any arg1, any arg2)` → `boolean`
* **`>`**: Greater than comparison
  * **Usage**: `fn(:>, float arg1, float arg2)` → `boolean`
* **`>=`**: Greater than or equal comparison
  * **Usage**: `fn(:>=, float arg1, float arg2)` → `boolean`
* **`between?`**: Check if value is between min and max
  * **Usage**: `fn(:between?, float arg1, float arg2, float arg3)` → `boolean`

## Math Functions

* **`abs`**: Absolute value
  * **Usage**: `fn(:abs, float arg1)` → `float`
* **`add`**: Add two numbers
  * **Usage**: `fn(:add, float arg1, float arg2)` → `float`
* **`ceil`**: Ceiling of number
  * **Usage**: `fn(:ceil, float arg1)` → `integer`
* **`clamp`**: Clamp value between min and max
  * **Usage**: `fn(:clamp, float arg1, float arg2, float arg3)` → `float`
* **`divide`**: Divide first number by second
  * **Usage**: `fn(:divide, float arg1, float arg2)` → `float`
* **`floor`**: Floor of number
  * **Usage**: `fn(:floor, float arg1)` → `integer`
* **`modulo`**: Modulo operation
  * **Usage**: `fn(:modulo, float arg1, float arg2)` → `float`
* **`multiply`**: Multiply two numbers
  * **Usage**: `fn(:multiply, float arg1, float arg2)` → `float`
* **`power`**: Raise first number to power of second
  * **Usage**: `fn(:power, float arg1, float arg2)` → `float`
* **`round`**: Round number to specified precision
  * **Usage**: `fn(:round, float1, float2, ...)` → `float`
* **`subtract`**: Subtract second number from first
  * **Usage**: `fn(:subtract, float arg1, float arg2)` → `float`
* **`tiered_sum`**: Accumulate over tiered ranges; returns [sum, marginal_rate]
  * **Usage**: `fn(:tiered_sum, float arg1, array(float) arg2, array(float) arg3)` → `array(float)`

## String Functions

* **`capitalize`**: Capitalize first letter of string
  * **Usage**: `fn(:capitalize, string arg1)` → `string`
* **`concat`**: Concatenate multiple strings
  * **Usage**: `fn(:concat, string1, string2, ...)` → `string`
* **`downcase`**: Convert string to lowercase
  * **Usage**: `fn(:downcase, string arg1)` → `string`
* **`end_with?`**: Check if string ends with suffix
  * **Usage**: `fn(:end_with?, string arg1, string arg2)` → `boolean`
* **`include?`**: Check if collection includes element
  * **Usage**: `fn(:include?, array(any) arg1, any arg2)` → `boolean`
* **`length`**: Get collection length
  * **Usage**: `fn(:length, array(any) arg1)` → `integer`
* **`start_with?`**: Check if string starts with prefix
  * **Usage**: `fn(:start_with?, string arg1, string arg2)` → `boolean`
* **`strip`**: Remove leading and trailing whitespace
  * **Usage**: `fn(:strip, string arg1)` → `string`
* **`upcase`**: Convert string to uppercase
  * **Usage**: `fn(:upcase, string arg1)` → `string`

## Collection Functions

* **`empty?`**: Check if collection is empty
  * **Usage**: `fn(:empty?, array(any) arg1)` → `boolean`
* **`first`**: Get first element of collection
  * **Usage**: `fn(:first, array(any) arg1)` → `any`
* **`include?`**: Check if collection includes element
  * **Usage**: `fn(:include?, array(any) arg1, any arg2)` → `boolean`
* **`last`**: Get last element of collection
  * **Usage**: `fn(:last, array(any) arg1)` → `any`
* **`length`**: Get collection length
  * **Usage**: `fn(:length, array(any) arg1)` → `integer`
* **`max`**: Find maximum value in numeric collection
  * **Usage**: `fn(:max, array(float) arg1)` → `float`
* **`min`**: Find minimum value in numeric collection
  * **Usage**: `fn(:min, array(float) arg1)` → `float`
* **`reverse`**: Reverse collection order
  * **Usage**: `fn(:reverse, array(any) arg1)` → `array(any)`
* **`size`**: Get collection size
  * **Usage**: `fn(:size, array(any) arg1)` → `integer`
* **`sort`**: Sort collection
  * **Usage**: `fn(:sort, array(any) arg1)` → `array(any)`
* **`sum`**: Sum all numeric elements in collection
  * **Usage**: `fn(:sum, array(float) arg1)` → `float`
* **`unique`**: Remove duplicate elements from collection
  * **Usage**: `fn(:unique, array(any) arg1)` → `array(any)`

## Conditional Functions

* **`coalesce`**: Return first non-nil value
  * **Usage**: `fn(:coalesce, any1, any2, ...)` → `any`
* **`conditional`**: Ternary conditional operator
  * **Usage**: `fn(:conditional, boolean arg1, any arg2, any arg3)` → `any`
* **`if`**: If-then-else conditional
  * **Usage**: `fn(:if, boolean1, boolean2, ...)` → `any`

## Type & Hash Functions

* **`at`**: Get element at index from array
  * **Usage**: `fn(:at, array(any) arg1, integer arg2)` → `any`
* **`fetch`**: Fetch value from hash with optional default
  * **Usage**: `fn(:fetch, hash(any, any)1, hash(any, any)2, ...)` → `any`
* **`has_key?`**: Check if hash has the given key
  * **Usage**: `fn(:has_key?, hash(any, any) arg1, any arg2)` → `boolean`
* **`keys`**: Get all keys from hash
  * **Usage**: `fn(:keys, hash(any, any) arg1)` → `array(any)`
* **`values`**: Get all values from hash
  * **Usage**: `fn(:values, hash(any, any) arg1)` → `array(any)`
