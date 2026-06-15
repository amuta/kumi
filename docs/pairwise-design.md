# Pairwise / cross-axis design notes

> **Status: implemented.** `cross` ships as a DSL primitive + `axis_cross` IR op.
> Verified end-to-end (Ruby + JS, bit-identical) on 1-D N-body; golden case
> `golden/pairwise_cross`. The notes below describe the design as built.


## What's already possible (verified)

A **decomposable** pairwise reduction — one that factors as
`result_i = f( Σ_j g(x_j), x_i )` — already works today, because:

- `fn(:sum, input.bodies.body.x)` reduces the whole `:body` axis to a scalar.
- A `scalar OP vector` expression broadcasts the scalar back across `:body`.

Verified: `fn(:sum, xs) - xi` over `[1,2,4]` yields `[6,5,3]`.

This covers center-of-mass, mean-field forces, "everyone vs the aggregate",
softmax denominators, normalization — anything linear/separable in the other
elements. The current `orbital-particles-3d` fakes gravity with a single origin
attractor precisely because the decomposable form was the only one available.

## What is NOT possible (verified)

A **non-decomposable** pairwise reduction, where the summand couples i and j
inseparably:

    accel_i = Σ_j  m_j * (x_j - x_i) / (|x_j - x_i|^3 + eps)   # true N-body

cannot be expressed. Referencing `input.bodies.body.x` twice does NOT produce an
N×N cross product — both references resolve to the **same axis name `:body`**, so
they iterate in lockstep (i == j). Verified: `abs(xi - xj)` yields `[0,0,0]`.

### Root cause

From `lib/kumi/ir/loop_definition.md`: an axis is identified by **name**, minted
from the input plan. `loop_start(source, axis, index)` opens one loop per axis;
`axis_index` reads "the index of the open loop *for that axis*." There is no way
to open two simultaneous loops over the same carrier with two distinct index
registers — both would claim `:body` and the broadcast/alignment machinery
collapses them.

So the gap is structural, not a missing function. It needs a primitive that
mints a **second, independent axis over the same carrier**.

## Design: `cross` (a.k.a. self-join axis)

Add a DSL primitive that takes a vector over axis `A` and re-exposes its carrier
under a fresh axis `A'`, so the two can be combined into a rank-2 (A × A')
intermediate, then reduced over `A'` back to rank-1 over `A`.

    let :xi, input.bodies.body.x                 # axis [:body]
    let :xj, cross(input.bodies.body.x)          # axis [:body_2]  (fresh carrier alias)
    let :dx, xj - xi                             # axis [:body, :body_2]  -> N×N
    let :inv, 1.0 / (fn(:abs, dx) + input.eps)
    value :potential, fn(:sum, inv, over: :body_2)   # reduce inner axis -> [:body]

Semantically `cross(v)` = "the whole of v, indexed by a new free axis." It is the
broadcast dual of a reduction: reduction removes an axis, `cross` introduces a
second copy of one.

### Why this fits the existing architecture

The IR already has every other ingredient:
- broadcasting a lower-rank value up to a higher-rank axis set (`align_axes`)
- reducing over an innermost axis suffix (`reduce` with `over_axes`)
- materializing an escaping vector with `array_init`/`array_push`

`cross` is the one missing op: introduce a new axis whose carrier is an existing
array. It is closely analogous to `axis_shift` (also a reindex of one axis), but
instead of `array[i - k]` it exposes `array[j]` for a *new* loop variable `j`.

## Implementation plan (layer by layer)

1. **DSL surface** — `lib/kumi/core/ruby_parser/schema_builder.rb`
   - Add `cross` to `DSL_METHODS`.
   - `def cross(arg, as: nil)` -> `CallExpression.new(:cross, [expr], { as: })`.
   - `as:` optionally names the new axis; default mints `"#{src_axis}__x"`.

2. **NAST / normalization** — mark `:cross` as an axis-introducing call (sibling
   of `shift`/`roll`). It does not lower to a kernel.

3. **Axis/shape analysis** (the real work) — wherever stamps/axes are computed
   (the analyzer pass that stamps `meta[:stamp][:axes]`):
   - `cross(v)` has axes = `axes_of(v) + [new_axis]`.
   - `new_axis` carrier == the carrier of `v`'s innermost axis (same array).
   - The new axis must be a first-class entry in the input-plan/axis table so
     `Loop::Lower` can resolve its carrier (reuse the source axis's plan_ref).

4. **DF lowering** — `lib/kumi/ir/df/lower.rb`
   - Add `emit_axis_cross(node, builder)` modeled on `emit_axis_shift`: emit a
     new `axis_cross` op carrying `{ source_axis:, new_axis: }`, with
     `axes: axes_of(node)` (= source axes + new axis).
   - Gate it in `emit_call` next to the `%i[shift roll]` check.

5. **Vec/Loop lowering** — `lib/kumi/ir/loop/lower.rb`
   - Lower `axis_cross` to a `loop_start(carrier, new_axis, new_index)` that
     iterates the **same carrier array** as `source_axis` but binds a distinct
     index register. Reads of the crossed value use `index_read(carrier, j)`.
   - Reduction over `new_axis` already works via the existing `over_axes` suffix
     path (the doc requires reduced axes to be an innermost suffix — `cross`
     naturally produces the new axis as the innermost, so `over: :body__x` is a
     clean suffix reduce).

6. **Codegen** — no emitter changes if `axis_cross` is fully lowered away in
   step 5 (the Loop validator forbids `axis_*` ops surviving). Emitters only see
   `loop_start`/`index_read`/`acc_*`, which already exist.

## Cost / risk

- **Perf:** O(N²) materialization is inherent to the math; the user opts in by
  writing `cross`. Loop fusion still applies to the inner body. For the 180-body
  orbital demo that's 32k iterations/step — fine in a worker.
- **Hardest step:** #3 (axis table must accept a synthesic axis backed by an
  existing carrier) and #5 (two loops, same carrier, distinct indices). Both are
  the same machinery `shift` already exercises, just introducing rather than
  reindexing an axis. Estimate: real but bounded — days, not the IR-rewrite weeks.
- **Validation:** the "reduced axes must be an innermost suffix" rule is the main
  invariant to respect; the `over: :new_axis` reduce satisfies it by construction.

## Smallest end-to-end slice to de-risk first

Before touching analysis, prototype the **runtime shape** with a hand-written
two-loop Ruby kernel to confirm the N×N-reduce result is what's wanted, then wire
`cross` from the DSL down. Decomposable cases need no new op and already ship.
