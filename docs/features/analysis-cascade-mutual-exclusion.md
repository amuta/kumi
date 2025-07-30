# Cascade Mutual Exclusion Detection

Analyzes cascade expressions to allow safe recursive patterns when conditions are mutually exclusive.

## Overview

The cascade mutual exclusion detector identifies when all conditions in a cascade expression cannot be true simultaneously, enabling safe mutual recursion patterns that would otherwise be rejected as cycles.

## Core Mechanism

The system performs three-stage analysis:

1. **Conditional Dependency Tracking** - DependencyResolver marks base case dependencies as conditional
2. **Mutual Exclusion Analysis** - UnsatDetector determines if cascade conditions are mutually exclusive  
3. **Safe Cycle Detection** - Toposorter allows cycles where all edges are conditional and conditions are mutually exclusive

## Example: Mathematical Predicates

```ruby
schema do
  input do
    integer :n
  end

  trait :n_is_zero, input.n, :==, 0
  trait :n_is_one, input.n, :==, 1

  value :is_even do
    on n_is_zero, true
    on n_is_one, false
    base fn(:not, is_odd)  # Safe mutual recursion
  end

  value :is_odd do
    on n_is_zero, false  
    on n_is_one, true
    base fn(:not, is_even)  # Safe mutual recursion
  end
end
```

## Safety Guarantees

**Allowed**: Cycles where conditions are mutually exclusive
- `n_is_zero` and `n_is_one` cannot both be true
- Base case recursion only occurs when both conditions are false
- Mathematical soundness preserved

**Rejected**: Cycles with overlapping conditions
```ruby
# This would be rejected - conditions can overlap
value :unsafe_cycle do
  on input.n > 0, "positive"
  on input.n > 5, "large"  # Both can be true!
  base fn(:not, unsafe_cycle)
end
```

## Implementation Details

### Conditional Dependencies
Base case dependencies are marked as conditional because they only execute when no explicit conditions match.

### Mutual Exclusion Analysis
Conditions are analyzed for mutual exclusion:
- Same field equality comparisons: `field == value1` vs `field == value2`
- Domain constraints ensuring impossibility
- All condition pairs must be mutually exclusive

### Metadata Generation
Analysis results stored in `cascade_metadata` state:
```ruby
{
  condition_traits: [:n_is_zero, :n_is_one],
  condition_count: 2,
  all_mutually_exclusive: true,
  exclusive_pairs: 1,
  total_pairs: 1
}
```

## Use Cases

- Mathematical predicates (even/odd, prime/composite)
- State machine fallback logic
- Recursive decision trees with termination conditions
- Complex business rules with safe defaults