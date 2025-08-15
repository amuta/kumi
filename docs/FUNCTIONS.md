# Kumi Standard Function Library Reference

Kumi provides a rich library of built-in functions for use within `value` and `trait` expressions via `fn(...)`.

## Logical Functions

* **`all?`**: Check if all elements in collection are truthy
  * **Usage**: `fn(:all?, array(any) arg1)` → `boolean`
* **`and`**: Logical AND of multiple conditions
  * **Usage**: `fn(:and, boolean1, boolean2, ...)` → `boolean`
* **`any?`**: Check if any element in collection is truthy
  * **Usage**: `fn(:any?, array(any) arg1)` → `boolean`
* **`cascade_and`**: **SYNTAX SUGAR ONLY** - Multi-condition cascade branches (NOT a real function)
  * **Usage**: `on trait1, trait2, result` (automatically becomes `cascade_and(trait1, trait2)`)
  * **Semantics**: Single condition → identity, multiple conditions → short-circuit AND
  * **Note**: This is pure syntax sugar; no `core.cascade_and` function exists in the registry
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
* **`piecewise_sum`**: Accumulate over tiered ranges; returns [sum, marginal_rate]
  * **Usage**: `fn(:piecewise_sum, float arg1, array(float) arg2, array(float) arg3)` → `array(float)`
* **`power`**: Raise first number to power of second
  * **Usage**: `fn(:power, float arg1, float arg2)` → `float`
* **`round`**: Round number to specified precision
  * **Usage**: `fn(:round, float1, float2, ...)` → `float`
* **`subtract`**: Subtract second number from first
  * **Usage**: `fn(:subtract, float arg1, float arg2)` → `float`

## String Functions

* **`capitalize`**: Capitalize first letter of string
  * **Usage**: `fn(:capitalize, string arg1)` → `string`
* **`concat`**: Concatenate multiple strings
  * **Usage**: `fn(:concat, string1, string2, ...)` → `string`
* **`contains?`**: Check if string contains substring
  * **Usage**: `fn(:contains?, string arg1, string arg2)` → `boolean`
* **`downcase`**: Convert string to lowercase
  * **Usage**: `fn(:downcase, string arg1)` → `string`
* **`end_with?`**: Check if string ends with suffix
  * **Usage**: `fn(:end_with?, string arg1, string arg2)` → `boolean`
* **`includes?`**: Check if string contains substring
  * **Usage**: `fn(:includes?, string arg1, string arg2)` → `boolean`
* **`length`**: Get string length
  * **Usage**: `fn(:length, string arg1)` → `integer`
* **`start_with?`**: Check if string starts with prefix
  * **Usage**: `fn(:start_with?, string arg1, string arg2)` → `boolean`
* **`string_include?`**: Check if string contains substring
  * **Usage**: `fn(:string_include?, string arg1, string arg2)` → `boolean`
* **`string_length`**: Get string length
  * **Usage**: `fn(:string_length, string arg1)` → `integer`
* **`strip`**: Remove leading and trailing whitespace
  * **Usage**: `fn(:strip, string arg1)` → `string`
* **`upcase`**: Convert string to uppercase
  * **Usage**: `fn(:upcase, string arg1)` → `string`

## Collection Functions

* **`all_across`**: Check if all elements are truthy across all nested levels
  * **Usage**: `fn(:all_across, array(any) arg1)` → `boolean`
* **`any_across`**: Check if any element is truthy across all nested levels
  * **Usage**: `fn(:any_across, array(any) arg1)` → `boolean`
* **`avg_if`**: Average values where corresponding condition is true
  * **Usage**: `fn(:avg_if, array(float) arg1, array(boolean) arg2)` → `float`
* **`build_array`**: Build array of given size with index values
  * **Usage**: `fn(:build_array, integer arg1)` → `array(any)`
* **`count_across`**: Count total elements across all nested levels
  * **Usage**: `fn(:count_across, array(any) arg1)` → `integer`
* **`count_if`**: Count number of true values in boolean array
  * **Usage**: `fn(:count_if, array(boolean) arg1)` → `integer`
* **`each_slice`**: Group array elements into subarrays of given size
  * **Usage**: `fn(:each_slice, array arg1, integer arg2)` → `array(array)`
* **`empty?`**: Check if collection is empty
  * **Usage**: `fn(:empty?, array(any) arg1)` → `boolean`
* **`first`**: Get first element of collection
  * **Usage**: `fn(:first, array(any) arg1)` → `any`
* **`flatten`**: Flatten nested arrays into a single array
  * **Usage**: `fn(:flatten, array(any) arg1)` → `array(any)`
* **`flatten_deep`**: Recursively flatten all nested arrays (alias for flatten)
  * **Usage**: `fn(:flatten_deep, array(any) arg1)` → `array(any)`
* **`flatten_one`**: Flatten nested arrays by one level only
  * **Usage**: `fn(:flatten_one, array(any) arg1)` → `array(any)`
* **`include?`**: Check if collection includes element
  * **Usage**: `fn(:include?, array(any) arg1, any arg2)` → `boolean`
* **`indices`**: Generate array of indices for the collection
  * **Usage**: `fn(:indices, array(any) arg1)` → `array(integer)`
* **`join`**: Join array elements into string with separator
  * **Usage**: `fn(:join, array arg1, string arg2)` → `string`
* **`last`**: Get last element of collection
  * **Usage**: `fn(:last, array(any) arg1)` → `any`
* **`map_add`**: Add value to each element
  * **Usage**: `fn(:map_add, array(float) arg1, float arg2)` → `array(float)`
* **`map_conditional`**: Transform elements based on condition: if element == condition_value then true_value else false_value
  * **Usage**: `fn(:map_conditional, array arg1, any arg2, any arg3, any arg4)` → `array`
* **`map_join_rows`**: Join 2D array into string with row and column separators
  * **Usage**: `fn(:map_join_rows, array(array) arg1, string arg2, string arg3)` → `string`
* **`map_multiply`**: Multiply each element by factor
  * **Usage**: `fn(:map_multiply, array(float) arg1, float arg2)` → `array(float)`
* **`map_with_index`**: Map collection elements to [element, index] pairs
  * **Usage**: `fn(:map_with_index, array(any) arg1)` → `array(any)`
* **`max`**: Find maximum value in numeric collection
  * **Usage**: `fn(:max, array(float) arg1)` → `float`
* **`min`**: Find minimum value in numeric collection
  * **Usage**: `fn(:min, array(float) arg1)` → `float`
* **`range`**: Generate range of integers from start to finish (exclusive)
  * **Usage**: `fn(:range, integer arg1, integer arg2)` → `array(integer)`
* **`reverse`**: Reverse collection order
  * **Usage**: `fn(:reverse, array(any) arg1)` → `array(any)`
* **`size`**: Get collection size
  * **Usage**: `fn(:size, array(any) arg1)` → `integer`
* **`sort`**: Sort collection
  * **Usage**: `fn(:sort, array(any) arg1)` → `array(any)`
* **`sum`**: Sum all numeric elements in collection
  * **Usage**: `fn(:sum, array(float) arg1)` → `float`
* **`sum_if`**: Sum values where corresponding condition is true
  * **Usage**: `fn(:sum_if, array(float) arg1, array(boolean) arg2)` → `float`
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
