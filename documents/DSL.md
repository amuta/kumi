# Kumi DSL Reference

Kumi is a declarative language for defining, analyzing, and executing complex business logic. It compiles rules into a verifiable dependency graph, ensuring that logic is **sound, maintainable, and free of contradictions** before execution (as much as possible given the current library implementation).

-----

## Guiding Principles

Kumi's design is opinionated and guides you toward creating robust and analyzable business logic.

  * **Logic as Code, Not Just Configuration**: Rules are expressed in a clean, readable DSL that can be version-controlled and tested.
  * **Provable Correctness**: A multi-pass analyzer statically verifies your schema, detecting duplicates, circular dependencies, type errors, and even **logically impossible conditions** (e.g., `age < 25 AND age > 65`) at compile time.
  * **Explicit Data Contracts**: The mandatory `input` block serves as a formal, self-documenting contract for the data your schema expects, enabling runtime validation of types and domain constraints.
  * **Composition Over Complexity**: Complex rules are built by composing simpler, named concepts (`trait`s), rather than creating large, monolithic blocks of logic.

-----

## Core Syntax

A Kumi schema contains an `input` block to declare its data contract, followed by `trait` and `value` definitions.

```ruby
schema do
  # 1. Define the data contract for this schema.
  input do
    # ... field declarations
  end

  # 2. Define reusable boolean predicates (traits).
  # ... trait definitions

  # 3. Define computed fields (values).
  # ... value definitions
end
```

-----

## Input Fields: The Data Contract

The `input` block declares the schema's data dependencies. All external data must be accessed via the `input` object (e.g., `input.age`).

### **Declaration Methods**

The preferred way to declare fields is with **type-specific methods**, which provide compile-time type checking and runtime validation.

  * **Primitives**:
    ```ruby
    string  :name
    integer :age, domain: 18..65
    float   :score, domain: 0.0..100.0
    boolean :is_active
    ```
  * **Collections**:
    ```ruby
    array :tags, elem: { type: :string }
    hash  :metadata, key: { type: :string }, val: { type: :any }
    ```

### **Domain Constraints**

Attach validation rules directly to input fields using `domain:`. These are checked when data is loaded.

  * **Range**: `domain: 1..100` or `0.0...1.0` (exclusive end)
  * **Enumeration**: `domain: %w[pending active archived]`
  * **Custom Logic**: `domain: ->(value) { value.even? }`

-----

## Traits: Named Logical Predicates

A **`trait`** is a named expression that **must evaluate to a boolean**. Traits are the fundamental building blocks of logic, defining reusable, verifiable conditions.

### **Defining & Composing Traits**

Traits are defined with a parenthesized expression and composed using the `&` operator. This composition is strictly **conjunctive (logical AND)**, a key constraint that enables Kumi's powerful static analysis.

```ruby
# Base Traits
trait :is_adult, (input.age >= 18)
trait :is_verified, (input.status == "verified")

# Composite Trait (is_adult AND is_verified)
trait :can_proceed, is_adult & is_verified

# Mix bare trait names with inline expressions
trait :is_eligible, is_adult & is_verified & (input.score > 50)
```

-----

## Values: Computed Fields

A **`value`** is a named expression that computes a field of any type.

### **Simple Values**

Values can be defined with expressions using `input` fields, functions (`fn`), and references to other values.

```ruby
value :full_name, fn(:concat, input.first_name, " ", input.last_name)
value :discounted_price, fn(:multiply, input.base_price, 0.8)
```

### **Conditional Values (Cascades)**

For conditional logic, a `value` takes a block to create a **cascade**. Cascades select a result based on a series of conditions, which **must reference named `trait`s**. This enforces clarity by separating the *what* (the condition's name) from the *how* (its implementation).

```ruby
value :access_level do
  # `on` implies AND: user must be :premium AND :verified.
  on :premium, :verified, "Full Access"

  # `on_any` implies OR: user can be :staff OR :admin.
  on_any :staff, :admin, "Elevated Access"

  # `on_none` implies NOT (A OR B): user is neither :blocked NOR :suspended.
  on_none :blocked, :suspended, "Limited Access"

  # `base` is the default if no other conditions match.
  base "No Access"
end
```

-----

## The Kumi Pattern: Separating AND vs. OR Logic

Kumi intentionally enforces a pattern for handling different types of logic to maximize clarity and analyzability.

  * **`trait`s and `&` are for AND logic**: Use `trait` composition to build up a set of conditions that must *all* be true. This is your primary tool for defining constraints.

  * **`value` cascades are for OR logic**: Use `on_any` within a `value` cascade to handle conditions where *any* one of several predicates is sufficient. This is the idiomatic way to express disjunctive logic.

This separation forces complex `OR` conditions to be handled within the clear, readable structure of a cascade, rather than being hidden inside a complex `trait` definition.

-----

## Best Practices

  * **Prefer Small, Composable Traits**: Avoid creating large, monolithic traits with many `&` conditions. Instead, define smaller, named traits and compose them.

    ```ruby
    # AVOID: Hard to read and reuse
    trait :eligible, (input.age >= 18) & (input.status == "active") & (input.score > 50)

    # PREFER: Clear, reusable, and self-documenting
    trait :is_adult, (input.age >= 18)
    trait :is_active, (input.status == "active")
    trait :has_good_score, (input.score > 50)
    trait :is_eligible, is_adult & is_active & has_good_score
    ```

  * **Name All Conditions**: If you need to use a condition in a `value` cascade, define it as a `trait` first. This gives the condition a clear business name and makes the cascade easier to read.