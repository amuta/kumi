# Kumi DSL Syntax Reference

This document provides a comprehensive comparison of Kumi's DSL syntax showing both the sugar syntax (convenient, readable) and the underlying sugar-free syntax (explicit function calls).

## Table of Contents

- [Schema Structure](#schema-structure)
- [Input Declarations](#input-declarations)
- [Value Declarations](#value-declarations)
- [Trait Declarations](#trait-declarations)
- [Expressions](#expressions)
- [Array Broadcasting](#array-broadcasting)
- [References](#references)

## Schema Structure

### Basic Schema Template

```ruby
module MySchema
  extend Kumi::Schema

  schema do
    input do
      # Input field declarations
    end

    # Traits and values using sugar syntax
  end
end
```

## Input Declarations

Input declarations are the same in both syntaxes:

```ruby
input do
  # Type-specific declarations
  integer :age, domain: 18..65
  string :status, domain: %w[active inactive suspended]
  float :score, domain: 0.0..100.0
  array :tags, elem: { type: :string }
  hash :metadata, key: { type: :string }, val: { type: :any }
  
  # Untyped fields
  any :misc_data
end
```

## Value Declarations

### Arithmetic Operations

```ruby
value :total_score, input.math_score + input.verbal_score + input.writing_score
value :average_score, total_score / 3
value :scaled_score, average_score * 1.5
value :final_score, scaled_score - input.penalty_points
```

### Mathematical Functions

```ruby
# With Sugar (Note: Some functions require sugar-free syntax)
value :score_variance, fn(:power, fn(:subtract, input.score, average_score), 2)
value :max_possible, fn(:max, [input.math_score, input.verbal_score, input.writing_score])
value :min_score, fn(:min, [input.math_score, input.verbal_score])

# Sugar-Free
value :score_variance, fn(:power, fn(:subtract, input.score, average_score), 2)
value :max_possible, fn(:max, [input.math_score, input.verbal_score, input.writing_score])
value :min_score, fn(:min, [input.math_score, input.verbal_score])
```

## Trait Declarations

### Comparison Operations

```ruby
# With Sugar
trait :high_scorer, input.total_score >= 1400
trait :perfect_math, input.math_score == 800
trait :needs_improvement, input.total_score < 1000
trait :above_average, input.average_score > 500

# Sugar-Free
trait :high_scorer, fn(:>=, input.total_score, 1400)
trait :perfect_math, fn(:==, input.math_score, 800)
trait :needs_improvement, fn(:<, input.total_score, 1000)
trait :above_average, fn(:>, input.average_score, 500)
```

### Logical Operations

```ruby
# With Sugar
trait :excellent_student, high_scorer & perfect_math
trait :qualified, (input.age >= 18) & (input.score >= 1200) & (input.status == "active")
trait :needs_review, needs_improvement & (input.attempts > 2)

# Sugar-Free
trait :excellent_student, fn(:and, high_scorer, perfect_math)
trait :qualified, fn(:and, fn(:and, fn(:>=, input.age, 18), fn(:>=, input.score, 1200)), fn(:==, input.status, "active"))
trait :needs_review, fn(:and, needs_improvement, fn(:>, input.attempts, 2))
```

### String Operations

```ruby
# All string operations use function syntax
trait :long_name, fn(:string_length, input.name) >  20
trait :starts_with_a, fn(:start_with?, input.name, "A")
trait :contains_space, fn(:contains?, input.name, " ")
```

## Expressions

### Complex Expressions

```ruby
value :weighted_score, (input.math_score * 0.4) + (input.verbal_score * 0.3) + (input.writing_score * 0.3)
value :percentile_rank, ((scored_better_than / total_students) * 100).round(2)
```

### Collection Operations

```ruby
value :total_scores, input.score_array.sum
value :score_count, input.score_array.size
value :unique_scores, input.score_array.uniq.size
value :sorted_scores, input.score_array.sort
```

## Array Broadcasting

Array broadcasting enables element-wise operations on array fields with automatic vectorization.

### Array Input Declarations

```ruby
input do
  # Structured array with defined fields
  array :line_items do
    float   :price
    integer :quantity
    string  :category
  end
  
  # Nested arrays with hash objects
  array :orders do
    array :items do
      hash :product do
        string :name
        float  :base_price
      end
      integer :quantity
    end
  end
  
  # Dynamic arrays with flexible element types
  array :api_responses do
    element :any, :response_data    # For dynamic/unknown hash structures
  end
  
  array :measurements do
    element :float, :value          # For simple scalar arrays
  end
end
```

### Element-wise Operations

```ruby
value :subtotals, input.line_items.price * input.line_items.quantity
trait :is_taxable, (input.line_items.category != "digital")
value :discounted_prices, input.line_items.price * 0.9
```

### Aggregation Operations

```ruby
value :total_subtotal, fn(:sum, subtotals)
value :avg_price, fn(:avg, input.line_items.price)
value :max_quantity, fn(:max, input.line_items.quantity)
value :item_count, fn(:size, input.line_items)
```

### Nested Array Access

```ruby
# With Sugar - Deep Field Access
value :all_product_names, input.orders.items.product.name
value :total_values, input.orders.items.product.base_price * input.orders.items.quantity
```

### Mixed Operations

```ruby
value :line_totals, input.items.price * input.items.quantity
value :order_total, fn(:sum, line_totals)
value :avg_line_total, fn(:avg, line_totals)
trait :has_expensive, fn(:any?, expensive_items)
```

## References

### Referencing Other Declarations

```ruby
# Both syntaxes (same)
trait :qualified_senior, qualified & (input.age >= 65)
value :bonus_points, qualified_senior ? 100 : 0

# Explicit reference syntax (both syntaxes)
trait :qualified_senior, ref(:qualified) & (input.age >= 65)
value :bonus_points, ref(:qualified_senior) ? 100 : 0
```

### Input Field References

```ruby
# Both syntaxes (same)
input.field_name          # Access input field
fn(:method, input.field_name)  # Call method on input field
```

## Complete Example Comparison

### With Sugar (Recommended)

```ruby
module StudentEvaluation
  extend Kumi::Schema

  schema do
    input do
      integer :math_score, domain: 0..800
      integer :verbal_score, domain: 0..800
      integer :writing_score, domain: 0..800
      integer :age, domain: 16..25
      string :status, domain: %w[active inactive]
    end

    # Calculated values with sugar
    value :total_score, input.math_score + input.verbal_score + input.writing_score
    value :average_score, total_score / 3
    value :scaled_average, fn(:round, average_score * 1.2, 2)

    # Traits with sugar
    trait :high_performer, total_score >= 2100
    trait :math_excellence, input.math_score >= 750
    trait :eligible_student, (input.age >= 18) & (input.status == "active")
    trait :scholarship_candidate, high_performer & math_excellence & eligible_student

    # Cascade with sugar-defined traits
    value :scholarship_amount do
      on scholarship_candidate, 10000
      on high_performer, 5000
      on math_excellence, 2500
      base 0
    end
  end
end
```