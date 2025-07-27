# Kumi DSL Syntax Reference

This document provides a comprehensive comparison of Kumi's DSL syntax showing both the sugar syntax (convenient, readable) and the underlying sugar-free syntax (explicit function calls).

## Table of Contents

- [Schema Structure](#schema-structure)
- [Input Declarations](#input-declarations)
- [Value Declarations](#value-declarations)
- [Trait Declarations](#trait-declarations)
- [Expressions](#expressions)
- [Functions](#functions)
- [Cascade Logic](#cascade-logic)
- [References](#references)

## Schema Structure

### Basic Schema Template

```ruby
# With Sugar (Recommended)
module MySchema
  extend Kumi::Schema

  schema do
    input do
      # Input field declarations
    end

    # Traits and values using sugar syntax
  end
end

# Sugar-Free (Explicit)
module MySchema
  extend Kumi::Schema

  schema do
    input do
      # Input field declarations (same)
    end

    # Traits and values using explicit function calls
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
# With Sugar
value :total_score, input.math_score + input.verbal_score + input.writing_score
value :average_score, total_score / 3
value :scaled_score, average_score * 1.5
value :final_score, scaled_score - input.penalty_points

# Sugar-Free
value :total_score, fn(:add, fn(:add, input.math_score, input.verbal_score), input.writing_score)
value :average_score, fn(:divide, total_score, 3)
value :scaled_score, fn(:multiply, average_score, 1.5)
value :final_score, fn(:subtract, scaled_score, input.penalty_points)
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
# With Sugar  
trait :long_name, input.name.length > 20
trait :starts_with_a, input.name.start_with?("A")
trait :contains_space, input.name.include?(" ")

# Sugar-Free
trait :long_name, fn(:>, fn(:string_length, input.name), 20)
trait :starts_with_a, fn(:start_with?, input.name, "A")
trait :contains_space, fn(:contains?, input.name, " ")
```

## Expressions

### Complex Expressions

```ruby
# With Sugar
value :weighted_score, (input.math_score * 0.4) + (input.verbal_score * 0.3) + (input.writing_score * 0.3)
value :percentile_rank, ((scored_better_than / total_students) * 100).round(2)

# Sugar-Free
value :weighted_score, fn(:add, 
  fn(:add, 
    fn(:multiply, input.math_score, 0.4), 
    fn(:multiply, input.verbal_score, 0.3)
  ), 
  fn(:multiply, input.writing_score, 0.3)
)
value :percentile_rank, fn(:round, 
  fn(:multiply, 
    fn(:divide, scored_better_than, total_students), 
    100
  ), 
  2
)
```

### Collection Operations

```ruby
# With Sugar
value :total_scores, input.score_array.sum
value :score_count, input.score_array.size
value :unique_scores, input.score_array.uniq.size
value :sorted_scores, input.score_array.sort

# Sugar-Free
value :total_scores, fn(:sum, input.score_array)
value :score_count, fn(:size, input.score_array)
value :unique_scores, fn(:size, fn(:unique, input.score_array))
value :sorted_scores, fn(:sort, input.score_array)
```

## Functions

### Built-in Functions Available

| Category | Sugar | Sugar-Free |
|----------|-------|------------|
| **Arithmetic** | `+`, `-`, `*`, `/`, `**` | `fn(:add, a, b)`, `fn(:subtract, a, b)`, etc. |
| **Comparison** | `>`, `<`, `>=`, `<=`, `==`, `!=` | `fn(:>, a, b)`, `fn(:<, a, b)`, etc. |
| **Logical** | `&` `|` | `fn(:and, a, b)`, `fn(:or, a, b)`, `fn(:not, a)` |
| **Math** | `abs`, `round`, `ceil`, `floor` | `fn(:abs, x)`, `fn(:round, x)`, etc. |
| **String** | `.length`, `.upcase`, `.downcase` | `fn(:string_length, s)`, `fn(:upcase, s)`, etc. |
| **Collection** | `.sum`, `.size`, `.max`, `.min` | `fn(:sum, arr)`, `fn(:size, arr)`, etc. |

### Custom Function Calls

```ruby
# With Sugar (when available)
value :clamped_score, input.raw_score.clamp(0, 1600)
value :formatted_name, input.first_name + " " + input.last_name

# Sugar-Free (always available)
value :clamped_score, fn(:clamp, input.raw_score, 0, 1600)
value :formatted_name, fn(:add, fn(:add, input.first_name, " "), input.last_name)
```

## Cascade Logic

Cascade syntax is the same in both approaches, but conditions use different syntax:

```ruby
# With Sugar
value :grade_letter do
  on :excellent_student, "A+"
  on :high_scorer, "A"
  on :above_average, "B"
  on :needs_improvement, "C"
  base "F"
end

# Sugar-Free  
value :grade_letter do
  on :excellent_student, "A+"
  on :high_scorer, "A"
  on :above_average, "B"
  on :needs_improvement, "C"
  base "F"
end
```

The difference is in how the traits referenced in cascade conditions are defined (see Trait Declarations above).

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
input.field_name.method   # Call method on input field (sugar)
fn(:method, input.field_name)  # Call method on input field (sugar-free)
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
      on :scholarship_candidate, 10000
      on :high_performer, 5000
      on :math_excellence, 2500
      base 0
    end
  end
end
```

### Sugar-Free (Explicit)

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

    # Calculated values without sugar
    value :total_score, fn(:add, fn(:add, input.math_score, input.verbal_score), input.writing_score)
    value :average_score, fn(:divide, total_score, 3)
    value :scaled_average, fn(:round, fn(:multiply, average_score, 1.2), 2)

    # Traits without sugar
    trait :high_performer, fn(:>=, total_score, 2100)
    trait :math_excellence, fn(:>=, input.math_score, 750)
    trait :eligible_student, fn(:and, fn(:>=, input.age, 18), fn(:==, input.status, "active"))
    trait :scholarship_candidate, fn(:and, fn(:and, high_performer, math_excellence), eligible_student)

    # Cascade with sugar-free defined traits
    value :scholarship_amount do
      on :scholarship_candidate, 10000
      on :high_performer, 5000
      on :math_excellence, 2500
      base 0
    end
  end
end
```

## When to Use Each Syntax

### Use Sugar Syntax When:
- ✅ Writing schemas by hand
- ✅ Readability is important
- ✅ Working with simple to moderate complexity
- ✅ You want concise, Ruby-like expressions

### Use Sugar-Free Syntax When:
- ✅ Generating schemas programmatically
- ✅ Building dynamic schemas in loops/methods
- ✅ You need explicit control over function calls
- ✅ Working with complex nested expressions
- ✅ Debugging expression evaluation issues

## Syntax Limitations

### Sugar Syntax Limitations:
- Supports `&` for logical AND (no `&&` due to Ruby precedence)
- Supports `|` for logical OR
- Limited operator precedence control
- Some Ruby methods not available as sugar

### Sugar-Free Advantages:
- Full access to all registered functions
- Clear operator precedence through explicit nesting
- Works in all contexts (including programmatic generation)
- More explicit about what operations are being performed

## Performance Notes

Both syntaxes compile to identical internal representations, so there is **no performance difference** between sugar and sugar-free syntax. Choose based on readability and maintenance needs.