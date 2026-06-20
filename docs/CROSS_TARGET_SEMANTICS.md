# Cross-Target Semantics

Kumi compiles one schema to **both Ruby and JavaScript**, and the central promise
is that the two targets compute **identical results**. Most operations are
identical for free (arithmetic, comparisons, array iteration). A handful are not,
because the two host languages disagree on edge-case behavior. This document is
the single place that records those cases and where each is pinned.

## Where the contract lives

Per-operation semantics live in **kernels**, one YAML entry per `(function,
target)`:

```
data/kernels/ruby/**/*.yaml         # Ruby implementation of each function
data/kernels/javascript/**/*.yaml   # JavaScript implementation of each function
```

A kernel has an `inline` form (expanded at the call site) and/or an `impl` form
(a named helper function emitted once per module). When Ruby and JS would
otherwise diverge, the kernels are written so **both produce the agreed result**,
and the YAML carries a comment pointing back here.

This is the configurable seam: changing a cross-target rule means editing the two
kernels (and the golden snapshots), not the compiler. Nothing in the analyzer or
emitters hard-codes these semantics.

> The Ruby and JS Loop emitters both support `impl`-only kernels (a kernel with
> no `inline` is emitted once as a module-level helper, `__<fn_id>(...)`), so a
> non-trivial rule can be a clean named function on both targets instead of an
> inline blob. See `codegen/loop/{ruby,js}/emitter.rb`.

## The pinned cases

### `to_string` of a float — keep the `.0`

A whole-valued float must stringify the same way on both targets.

| value     | Ruby `to_s` | JS `String()` | Kumi (both) |
| --------- | ----------- | ------------- | ----------- |
| `3.0`     | `"3.0"`     | `"3"`         | `"3.0"`     |
| `100.0`   | `"100.0"`   | `"100"`       | `"100.0"`   |
| `-0.0`    | `"-0.0"`    | `"0"`         | `"-0.0"`    |
| `1e21`    | `"1.0e+21"` | `"1e+21"`     | `"1.0e+21"` |
| `1e-7`    | `"1.0e-07"` | `"1e-7"`      | `"1.0e-07"` |

The contract is **Ruby's `Float#to_s`** (the float dtype stays visible in the
string). JS cannot distinguish `3` (integer) from `3.0` (float) at runtime, so
this is a **dtype-dispatched overload**: `core.to_string:float` (param
`dtype: float`) is selected for float arguments by overload resolution, and its
JS kernel reproduces Ruby's formatting (mantissa `.0`, signed zero-padded
exponent, `-0.0` sign). Non-float `to_string` keeps the plain `String($0)`.

Kernels: `to_string_float:ruby:v1`, `to_string_float:javascript:v1`.

### `to_integer` / `to_float` of a string — Ruby parsing, not JS parsing

`String#to_i` / `String#to_f` and JS `parseInt` / `parseFloat` disagree:

| input      | Ruby `to_i` | JS `parseInt` | Kumi (both) |
| ---------- | ----------- | ------------- | ----------- |
| `"abc"`    | `0`         | `NaN`         | `0`         |
| `""`       | `0`         | `NaN`         | `0`         |
| `"0x1f"`   | `0`         | `31` (hex)    | `0`         |
| `"12abc"`  | `12`        | `12`          | `12`        |

The contract is **Ruby's** behavior: a non-numeric string is the type's zero
(`0` / `0.0`), parsing is base-10 (no `0x` hex), and a numeric value truncates
toward zero with `Math.trunc` (JS `parseInt(1e-7)` is the wrong `1`). The JS
kernels are written to match.

Kernels: `to_integer:javascript:v1`, `to_float:javascript:v1`.

### `pow` of a negative base with a fractional exponent — NaN, not Complex

`(-8.0) ** (1.0/3)` is mathematically complex. Ruby returns a `Complex`; JS
`Math.pow` returns `NaN`. A numeric DSL should not silently produce complex
numbers, so the **contract is `NaN`** (matching JS). The Ruby kernel collapses a
`Complex` result to `Float::NAN`.

Kernel: `pow:ruby:v1`.

## Not divergences (documented to prevent false alarms)

- **`mean` / `sum` / `min` / `max` of an empty array.** `mean([])` is `NaN` on
  *both* targets (`0.0 / 0`). When probing via JSON, note `JSON.stringify(NaN)`
  is `"null"`, so a Ruby `NaN` looks like a JS `null` through a JSON round-trip —
  that is a serialization artifact, not a semantic difference.

## Adding or changing a rule

1. Decide the agreed result for both targets.
2. Edit the Ruby kernel and the JS kernel so each produces it (add a `# see
   docs/CROSS_TARGET_SEMANTICS.md` comment and a row in this file).
3. Regenerate the golden snapshots: `bin/kumi golden_v2 update`. The
   `runtime.json` of any affected golden should change only where the old
   behavior was actually wrong.
4. Add a parity case (Ruby vs generated-JS over edge inputs) so the contract is
   tested, not just documented.
