# IR Goals And Current Plan

This document records the intended direction for Kumi's new IR stack and the
current implementation plan.

It is not a full architecture reference. The goal here is to keep a clear
working contract:

- what each IR layer owns
- what must not leak into emitters
- what each validator must enforce
- how `golden_v2` should be used while the refactor is underway

See also:

- [docs/ARCHITECTURE.md](./ARCHITECTURE.md)
- [lib/kumi/ir/README.md](../lib/kumi/ir/README.md)
- [lib/kumi/ir/vec_definition.md](../lib/kumi/ir/vec_definition.md)

## Desired Goals

### 1. IRs own semantics, emitters do not

Ruby and JavaScript emitters should be as dumb as possible.

That means:

- no shape inference in emitters
- no axis semantics being reconstructed in emitters
- no backend-specific compensation for unclear IR contracts
- no "if this is 1D do X, otherwise fail" logic unless the IR layer itself has
  deliberately declared that limitation

The compiler should normalize meaning before codegen.

### 2. Each IR layer has one job

The intended split is:

- **DFIR**
  - lower from SNAST into graph form
  - normalize input traversal
  - canonicalize access paths
  - handle imports and local graph cleanup
  - normalize tuple/object structure before vector semantics become explicit
  - preserve functional and array semantics without target-specific behavior

- **VecIR**
  - represent pure axis-aware value semantics
  - require axes and dtype on every value
  - keep broadcasts, shifts, indices, maps, selects, and reductions declarative
  - run deterministic vector-level rewrites and canonicalization
  - avoid execution, storage, and target syntax concerns

- **LoopIR**
  - materialize execution structure from VecIR
  - own iteration, broadcasts, reductions, and index-driven execution behavior
  - represent vector/object assembly in execution form
  - prevent emitters from inferring axes, rediscovering broadcasts, or branching
    on vector rank to decide semantics

- **BufIR**
  - own allocation, lifetimes, temporary buffers, object/array layout, and
    ABI-visible materialization
  - exist as a real phase only if LoopIR would otherwise absorb storage policy
    or emitters still need storage/layout knowledge

- **Emitters**
  - serialize already-normalized LoopIR or BufIR into Ruby/JS
  - own target syntax, naming, literal formatting, helper emission, and minor
    target conventions

### 3. Passes should be deterministic and easy to reason about

A good pass should:

- have a small and explicit contract
- say what invariants it expects on input
- say what invariants it guarantees on output
- fail loudly if its input contract is violated

The desired feel is compiler-pipeline clarity, not heuristic cleanup.

### 4. Feedback loops must be phase-scoped

We need to be able to validate frontend, DFIR, VecIR, and LoopIR independently.

Late codegen failures must not block inspection of early representations.

This is especially important while LoopIR and BufIR are still settling.

## Current Reality

The codebase already has the right high-level direction, but some boundaries are
not fully enforced yet.

### What is already in place

- explicit IR namespaces for DF, Vec, Loop, and Buf
- dedicated Vec pipeline passes
- analyzer state storing intermediate modules
- `golden_v2` as a simpler, phase-scoped golden harness
- explicit validation passes at IR boundaries:
  - `DFValidatePass`
  - `VecValidatePass`
  - `LoopValidatePass`

### Current mismatches with the desired design

- LoopIR is still too close to VecIR in some paths and does not yet fully own
  the semantics of `axis_index`, `axis_shift`, broadcast, and reduction
  materialization.
- Emitters still contain semantic logic that should move upward into LoopIR or
  BufIR.
- Some IR contracts are still ambiguous, especially around input traversal and
  access-path lowering.
- Some validators currently reflect the implemented IR rather than the final
  intended IR. That is acceptable short term, but should converge over time.

## Current Plan

The work should proceed in this order.

### Phase 1. Keep the feedback loop fast

Use `golden_v2` as the phase-scoped refactor harness.

The target workflow is:

```bash
bundle exec bin/kumi golden_v2 verify --repr frontend <schema>
bundle exec bin/kumi golden_v2 verify --repr df <schema>
bundle exec bin/kumi golden_v2 verify --repr vec <schema>
bundle exec bin/kumi golden_v2 verify --repr loop <schema>
bundle exec bin/kumi golden_v2 verify --repr codegen <schema>
```

Rules for this phase:

- confirm the existing `frontend`, `df`, `vec`, `loop`, and `codegen` groups can
  be inspected independently
- treat `golden_v2` as a harness, not as a refactor target
- do not inspect or modify generated artifacts except when checking a focused
  representation diff
- do not let late emitter failures block inspection of earlier IRs

### Phase 2. Lock the DF input/access contract

Fix the earliest known ambiguous contract before deeper LoopIR work.

DFIR must have a written and tested input/access contract that defines:

- how SNAST `InputRef` nodes map to DFIR `load_input` and `load_field`
- which part of the path is the root input key
- which part of the path is represented as a chain
- how array element traversal is represented
- when two loads are identical and may be deduplicated
- what access-path forms are invalid and must fail validation

Do not patch emitters for input traversal bugs. If traversal is duplicated or
ambiguous in DF lowering, fix DF lowering or the access contract.

### Phase 3. Lock contracts for VecIR, LoopIR, and BufIR

Before adding more lowering behavior, each layer should have a short written and
tested contract.

At minimum:

- what op families are legal in DFIR after structural cleanup
- what axis and dtype invariants VecIR guarantees
- what it means for LoopIR to be materialized enough for codegen
- what storage concerns would require BufIR now

Validators are the executable form of those contracts. They should reject
ambiguous access paths, unsupported LoopIR semantic leaks, unaligned VecIR
operations, bad reduction axes, and incomplete materialization before emitters
run.

Validator tests should include negative cases for illegal states, not only
golden snapshots of successful pipelines.

### Phase 4. Define LoopIR's concrete execution boundary

LoopIR should become the place where vector semantics are turned into explicit
execution structure.

LoopIR is materialized enough for codegen only when:

- no raw VecIR-only ops remain in LoopIR
- broadcasts are explicit as execution structure or intentionally erased only
  when proven no-op
- `axis_index` is represented as execution-level index access
- `axis_shift` is represented as deterministic shifted read/index behavior with
  policy
- reductions expose accumulator/init/step/final result behavior clearly enough
  that emitters serialize rather than invent folds
- vector object assembly has explicit execution/materialization shape or is
  rejected by LoopIR validation before codegen

The important point is not just "support these ops". The important point is that
after LoopIR, emitters should not be asked to rediscover their meaning.

### Phase 5. Implement LoopIR lowering against the contract

Once the LoopIR boundary is explicit, lower VecIR features into that shape.

Priority items:

- `axis_index`
- `axis_shift`
- broadcast materialization
- reduction execution structure
- tuple/object assembly behavior in loop context

If VecIR contains semantics that cannot be represented cleanly in LoopIR, either
fix VecIR lowering or introduce a better intermediate form. Do not compensate in
Ruby or JavaScript emitters.

### Phase 6. Decide whether BufIR becomes a real boundary now

Decide this with a narrow spike, not a broad redesign.

Use a small representative slice:

- one 2D elementwise operation
- one shifted read
- one reduction
- one vector object/array materialization case

BufIR should become a real phase if either of these becomes true:

- LoopIR starts owning allocation/storage concerns
- emitters still need to know too much about temporary objects, layout, or
  materialization strategy

If LoopIR can remain a pure execution layer and codegen can serialize it
directly, BufIR can stay minimal for now.

If not, BufIR should become the storage boundary deliberately rather than
accidentally.

### Phase 7. Shrink emitters

Once LoopIR or BufIR carries enough structure:

- move shape branching out of Ruby/JS emitters
- move semantic lowering out of Ruby/JS emitters
- leave emitters responsible mostly for syntax emission and small target
  conventions

This is one of the main success criteria for the whole refactor.

## What "Right Place" Means

When making a change, use this decision rule:

- If the problem is about meaning, shape, axes, traversal, broadcast, or
  reduction semantics, it belongs in DFIR/VecIR/LoopIR.
- If the problem is about buffers, materialized objects, layout, or ownership,
  it probably belongs in BufIR.
- If the problem is only about surface syntax for Ruby or JavaScript, it belongs
  in the emitter.

If a backend patch "fixes" a semantic bug from an earlier layer, that is usually
the wrong place.

## Near-Term Deliverables

The next useful milestones are:

1. confirm `golden_v2` phase inspection for `frontend`, `df`, `vec`, `loop`, and
   `codegen`
2. lock and test the DF input/access contract
3. define better LoopIR contracts and validators
4. move `axis_index` / `axis_shift` semantics out of emitters and into LoopIR
   lowering
5. decide whether BufIR should become a real lowering target now
6. shrink Ruby/JS emitters after LoopIR or BufIR carries the needed structure

## Success Criteria

This refactor is on the right track when the following become true:

- early IR representations can be verified without full codegen
- validators clearly explain what each boundary guarantees
- invalid intermediate states fail before codegen
- LoopIR is more than a renamed VecIR
- emitters become mechanical instead of semantic
- golden failures tell us which layer regressed, not just that "something
  failed later"
