# UNSAT Detection & Constraint Analysis

Kumi includes static analysis to detect **unsatisfiable constraints**—impossible conditions that can never be true given input domains.

## How It Works

### Direct Contradictions
Kumi detects when the same variable is constrained to multiple different values:

```ruby
schema do
  input { integer :x }

  # ✓ Detected as UNSAT: x cannot be both 5 and 10
  trait :impossible, fn(:and, input.x == 5, input.x == 10)
end
```

### Domain Violations
Kumi checks when constraints violate input domains:

```ruby
schema do
  input { integer :age, domain: 0..150 }

  # ✓ Detected as UNSAT: age can never be 200
  trait :impossible_age, input.age == 200
end
```

### Constraint Propagation (Phase 2)
Kumi propagates constraints through operations to detect derived impossibilities:

```ruby
schema do
  input { integer :x, domain: 0..10 }

  value :doubled, fn(:mul, input.x, 2)  # doubled ∈ [0, 20]

  # ✓ Detected as UNSAT: doubled can never be 50
  trait :impossible_doubled, doubled == 50
end
```

**Reverse propagation** derives input constraints from output constraints:

```ruby
schema do
  input { integer :x, domain: 0..10 }

  value :result, fn(:add, input.x, 100)  # result ∈ [100, 110]

  # ✓ Detected as UNSAT: result == 50 would require x == -50 (outside domain)
  trait :impossible_result, result == 50
end
```

## Error Messages

Impossible constraints raise `Kumi::Core::Errors::SemanticError`:

```
conjunction `impossible_doubled` is impossible
```

This message appears at schema compilation time, catching bugs before execution.

## When UNSAT Detection Runs

UNSAT detection is performed during the **HIR-to-LIR compilation phase**, after:
- Function IDs are resolved
- Type information is inferred
- Dimensional metadata is computed

This ensures detection has access to complete operation semantics.

## Future Enhancements

- **Multi-level propagation**: Chain constraints through multiple operations
- **Inequality constraints**: Handle `<`, `>`, `<=`, `>=` constraints
- **Combined constraints**: Detect contradictions across multiple traits

See `spec/integration/unsat_with_propagation_spec.rb` for examples and pending tests.
