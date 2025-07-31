# Cascade Mutual Exclusion Detection

Analyzes cascade expressions to allow safe recursive patterns when conditions are mutually exclusive.

## Overview

The cascade mutual exclusion detector identifies when all conditions in a cascade expression cannot be true simultaneously, enabling safe mutual recursion patterns that would otherwise be rejected as cycles.

## Core Mechanism

The system performs three-stage analysis:

1. **Conditional Dependency Tracking** - DependencyResolver marks base case dependencies as conditional
2. **Mutual Exclusion Analysis** - UnsatDetector determines if cascade conditions are mutually exclusive  
3. **Safe Cycle Detection** - Toposorter allows cycles where all edges are conditional and conditions are mutually exclusive

## Example: Processing Workflow

```ruby
schema do
  input do
    string :operation  # "forward", "reverse", "unknown"
    integer :value
  end

  trait :is_forward, input.operation == "forward"
  trait :is_reverse, input.operation == "reverse"

  # Safe mutual recursion - conditions are mutually exclusive
  value :forward_processor do
    on is_forward, input.value * 2        # Direct calculation
    on is_reverse, reverse_processor + 10  # Delegates to reverse (safe)
    base "invalid operation"               # Fallback for unknown operations
  end

  value :reverse_processor do
    on is_forward, forward_processor - 5   # Delegates to forward (safe)
    on is_reverse, input.value / 2         # Direct calculation
    base "invalid operation"               # Fallback for unknown operations
  end
end
```

## Safety Guarantees

**Allowed**: Cycles where conditions are mutually exclusive
- `is_forward` and `is_reverse` cannot both be true (operation has single value)
- Each recursion executes exactly one step before hitting direct calculation
- Bounded recursion with guaranteed termination

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
  condition_traits: [:is_forward, :is_reverse],
  condition_count: 2,
  all_mutually_exclusive: true,
  exclusive_pairs: 1,
  total_pairs: 1
}
```

## Use Cases

- Processing workflows with bidirectional logic
- State machine fallback patterns  
- Recursive decision trees with termination conditions
- Complex business rules with safe delegation patterns