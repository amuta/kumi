# Kumi Compiler Architecture

This document describes the intended end-state architecture for Kumi's compiler.


## Overview

Kumi should compile schemas through a small number of explicit semantic layers.

The architecture goal is:

- semantics become more explicit as the pipeline progresses
- each layer owns one kind of transformation
- invariants are validated at layer boundaries
- backends emit syntax from normalized IR, not meaning from partially-lowered IR

The intended pipeline is:

```text
Schema / Frontend AST
  -> NAST
  -> SNAST
  -> DFIR
  -> VecIR
  -> LoopIR
  -> BufIR (when needed)
  -> Target Emitters (Ruby / JavaScript / others)
```

## Design Principles

### IRs own semantics

Meaning should be resolved before codegen.

That means:

- access semantics belong in the IR pipeline
- axis semantics belong in the IR pipeline
- reduction semantics belong in the IR pipeline
- iteration and execution structure belong in LoopIR
- allocation and storage belong in BufIR

Emitters should not reconstruct these concepts from ad hoc patterns.

### Passes are deterministic

Every pass should have a small contract:

- what it expects on input
- what it guarantees on output
- what invariants it validates

The pipeline should feel like a compiler, not a collection of backend-driven
patches.

### Validation is explicit

Each major IR boundary should end with a validator pass. Validators are not
optional diagnostics; they are the executable form of the architecture.

Examples:

- `DFValidatePass`
- `VecValidatePass`
- `LoopValidatePass`

These passes should fail loudly when earlier layers leak invalid structure.

### Feedback loops are phase-scoped

The compiler must support inspecting and verifying intermediate layers without
requiring the full pipeline to succeed.

That is why golden inspection should be grouped by stage:

- `frontend`
- `df`
- `vec`
- `loop`
- `codegen`

This keeps refactors local and keeps late backend failures from hiding earlier
IR issues.

## Layer Responsibilities

### Frontend AST, NAST, and SNAST

These layers own source-language normalization and semantic preparation.

- **Frontend AST**
  - parser output
  - syntax-oriented
  - still close to source shape

- **NAST**
  - normalized AST form
  - removes frontend-specific irregularity

- **SNAST**
  - semantic AST with dimensional/type metadata
  - explicit enough to lower into IR

These layers should not be burdened with backend concerns.

### DFIR

DFIR is the first real execution-oriented semantic layer.

It should:

- lower from SNAST
- represent functional/array semantics directly
- normalize input traversal and access paths
- carry reductions, selection, imports, tuples, object construction, and other
  graph-level operations
- perform structural cleanup before vector semantics become explicit

DFIR is where we should fix bugs about:

- duplicated or ambiguous input access
- import inlining behavior
- tuple/object canonicalization
- graph structure before vector execution is considered

DFIR should not be target-specific.

### VecIR

VecIR represents explicit axis-aware value semantics.

It should:

- make axes and dtype metadata explicit on every value
- represent broadcasts, shifts, indices, maps, selects, and reductions in a
  uniform vector form
- run deterministic vector-level optimization and canonicalization passes
- remain pure and declarative

VecIR is not the right place for target syntax or loop syntax. It is the layer
where array semantics become explicit, but not yet materialized into execution.

### LoopIR

LoopIR is the semantic execution layer.

It should:

- materialize iteration structure from VecIR
- make index-driven execution explicit
- own the meaning of broadcasts and reductions as execution constructs
- remove the need for emitters to rediscover vector semantics

The key test for LoopIR is simple:

If a backend still needs to understand vector semantics in order to emit code,
LoopIR is not finished.

LoopIR should be where:

- `axis_index` becomes execution-level index behavior
- `axis_shift` becomes deterministic loop/index materialization
- reductions become explicit iteration/accumulation structure
- vector/object assembly becomes execution-shaped

### BufIR

BufIR is the storage/materialization boundary.

It should exist as a real lowering stage if:

- allocation strategy becomes important
- temporary buffers need explicit ownership
- materialized objects/arrays need explicit layout
- backend codegen still has to reason about storage rather than syntax

BufIR should own:

- allocations
- lifetimes
- buffer writes/reads
- layout-visible materialization

If LoopIR is purely execution-shaped and targets can emit directly from it,
BufIR can stay minimal. If not, BufIR should become the deliberate boundary
rather than an accidental grab-bag.

### Emitters

Emitters should be mechanical.

They should:

- serialize normalized IR into Ruby/JS syntax
- handle target naming conventions
- handle small target-specific syntax details

They should not:

- infer shapes
- reconstruct broadcasts
- reinterpret axis semantics
- compensate for incomplete lowering

The architecture is healthy when emitter code is boring.

## Boundary Validators

Each IR boundary should have a validator that explains the layer contract in
executable form.

Examples of the intended role:

- **DF validator**
  - legal op families
  - consistent access-path rules
  - object/tuple construction sanity
  - reduction shape rules

- **Vec validator**
  - legal vector op families
  - axis consistency
  - broadcast correctness
  - reduction metadata correctness

- **Loop validator**
  - legal execution-level op families
  - no unsupported vector semantics leaking through
  - return/value consistency
  - execution-structure sanity

Validators are part of the design, not merely tests.

## Golden and Inspection Strategy

The intended verification model is staged.

Use `golden_v2` to inspect and verify layers independently:

```bash
bundle exec bin/kumi golden_v2 verify --repr frontend <schema>
bundle exec bin/kumi golden_v2 verify --repr df <schema>
bundle exec bin/kumi golden_v2 verify --repr vec <schema>
bundle exec bin/kumi golden_v2 verify --repr loop <schema>
bundle exec bin/kumi golden_v2 verify --repr codegen <schema>
```

This should be the normal workflow during IR refactors.

End-to-end runtime verification remains important, but it should be the last
step, not the only source of signal.

## Ownership Rules

Use this rule when deciding where a fix belongs:

- If the problem is about meaning, traversal, axes, broadcast, reduction, or
  execution semantics, it belongs in DFIR/VecIR/LoopIR.
- If the problem is about materialization, layout, ownership, or temporary
  storage, it belongs in BufIR.
- If the problem is purely about emitted target syntax, it belongs in the
  emitter.

If a backend patch compensates for an earlier semantic bug, that is usually the
wrong place to fix it.

## Success Criteria

This architecture is achieved when:

- IR layers have stable, narrow responsibilities
- validators make contracts explicit
- LoopIR is materially more than a renamed VecIR
- BufIR exists only if it carries real storage meaning
- emitters become mostly mechanical
- golden failures identify the broken layer directly

