# Golden Tests Guide

Golden tests verify schema compilation and execution end to end: every schema
under `golden/` is compiled through the full pipeline, its intermediate
representations are snapshot-checked, and the generated Ruby and JavaScript
are executed against real input and compared to expected output.

## Structure

```
golden/my_test/
├── schema.kumi        # Schema under test
├── input.json         # Test input (may contain multiple named cases)
├── expected.json      # Expected execution output
└── expected/          # Generated representations (auto-created)
    ├── ast.txt  input_plan.txt  nast.txt  snast.txt
    ├── dfir.txt  dfir_optimized.txt  vecir.txt  loopir.txt
    ├── schema_ruby.rb
    └── schema_javascript.mjs
```

## Creating a Test

```bash
mkdir -p golden/my_test
```

**schema.kumi** — keep it focused on one feature (10–30 lines):

```ruby
schema do
  input do
    integer :age
    float :salary
  end

  value :adjusted, input.salary * 1.05
end
```

**input.json:**

```json
{ "age": 30, "salary": 100000.0 }
```

**expected.json** — calculate by hand first:

```json
{ "adjusted": 105000.0 }
```

Then generate and run:

```bash
bin/kumi golden update my_test   # writes expected/ representations
bin/kumi golden test my_test     # executes Ruby + JS against input.json
git add golden/my_test/
```

## Commands

There are two harnesses with different jobs.

**`golden` — runtime ground truth.** Regenerates representations, then
executes the generated Ruby and JavaScript and compares results to
`expected.json`:

| Command | Purpose |
|---------|---------|
| `bin/kumi golden list` | List all tests |
| `bin/kumi golden test [names...]` | Regenerate + execute |
| `bin/kumi golden update [names...]` | Regenerate expected files |
| `bin/kumi golden verify [names...]` | Diff representations only |

**`golden_v2` — phase-scoped snapshots.** Verifies one IR layer at a time, so
a broken later phase never hides an earlier one:

| Command | Purpose |
|---------|---------|
| `bin/kumi golden_v2 verify --repr <group>` | Check one layer across schemas |
| `bin/kumi golden_v2 update --repr <group>` | Regenerate one layer |
| `bin/kumi golden_v2 diff --repr <group>` | Show unified diffs |
| `bin/kumi golden_v2 reprs` | List representations and groups |

Groups: `frontend` (ast, input_plan, nast, snast), `df`, `vec`, `loop`,
`codegen`, `all`.

## Debugging a Failure

Work from the earliest layer outward:

```bash
# Print a single representation for one schema (fastest feedback)
bin/kumi pp loopir golden/my_test/schema.kumi
bin/kumi pp dfir_optimized golden/my_test/schema.kumi

# Find which schemas crash a lowering phase
for d in golden/*/; do bin/kumi pp loopir "$d/schema.kumi" >/dev/null || echo "$d"; done

# Inspect generated code
cat golden/my_test/expected/schema_ruby.rb
```

Large goldens (`game_of_life`, `us_tax_2024`) are huge — grep them rather
than reading whole files.

## Patterns

**Broadcast and reduce** (from `golden/simple_math`-style schemas):

```ruby
schema do
  input do
    array :items do
      hash :item do
        integer :quantity
        integer :unit_price
      end
    end
  end

  value :line_totals, input.items.item.quantity * input.items.item.unit_price
  value :subtotal, fn(:sum, line_totals)
end
```

**Cascade logic** (from `golden/cascade_logic`):

```ruby
schema do
  input do
    integer :x
    integer :y
  end

  trait :x_positive, input.x > 0
  trait :y_positive, input.y > 0

  value :status do
    on y_positive, x_positive, "both positive"
    on x_positive, "x positive"
    on y_positive, "y positive"
    base "neither positive"
  end
end
```

## Best Practices

1. **One feature per schema** — `cascade_logic`, not `test1`
2. **Round numbers** — easy to verify by hand
3. **Review the generated code** — `expected/schema_ruby.rb` is part of the
   contract; readable diffs are the point
4. **Test edge cases** — empty arrays, null, zero, negative values
5. **Commit `expected/`** — golden diffs in review are how regressions are
   caught

## Updating After Intentional Changes

```bash
bin/kumi golden update my_test
git diff golden/my_test/expected/   # review every changed line
```

A compiler change should only alter the layers it claims to touch — if a
DFIR-only change shows up in `loopir.txt` diffs, that's a finding.
