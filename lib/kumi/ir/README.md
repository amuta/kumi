# Kumi IR Architecture

This directory contains the compiler IR stack that sits between SNAST and
target code generation.

For the broader compiler view, see
[docs/ARCHITECTURE.md](../../../docs/ARCHITECTURE.md).

## Goals

The IR stack exists to make semantics explicit before codegen.

The core goals are:

- each layer owns one kind of transformation
- passes are deterministic and easy to reason about
- boundary validators define and enforce invariants
- emitters become mechanical serializers over normalized IR

The pipeline is:

```text
SNAST
  -> DFIR
  -> VecIR
  -> LoopIR
  -> BufIR (when needed)
  -> Ruby / JavaScript / other emitters
```

## Layers

### Base

Shared IR scaffolding:

- instructions
- blocks
- functions
- modules
- builders

These classes provide common structure and should not carry layer-specific
semantics.

### DFIR

DFIR is the first explicit semantic IR after SNAST.

It should:

- lower semantic AST into graph form
- normalize access paths
- represent functional/array semantics directly
- perform structural rewrites before vector semantics are materialized

DFIR owns graph meaning, not backend syntax.

### VecIR

VecIR makes axis-aware value semantics explicit.

It should:

- carry axes and dtype on every value
- represent broadcasts, shifts, indices, maps, selects, and reductions
- run deterministic vector-level canonicalization and optimization
- remain pure and declarative

VecIR should not yet encode execution structure.

See [vec_definition.md](./vec_definition.md).

### LoopIR

LoopIR is the execution-materialization layer.

It should:

- turn VecIR semantics into explicit iteration structure
- own the execution meaning of indices, shifts, broadcasts, and reductions
- remove the need for emitters to understand vector semantics directly

LoopIR is the last semantic layer before storage concerns.

See [loop_definition.md](./loop_definition.md).

### BufIR

BufIR is the explicit storage/materialization layer.

It should only become a substantial layer when needed, but when it exists, it
owns:

- allocations
- lifetimes
- buffer layout-visible materialization
- storage-oriented lowering decisions

If backend codegen still has to reason about storage, BufIR is the right place
for that logic.

## Validators

Every major IR boundary should end with a validator pass.

Validators are part of the architecture, not optional helpers.

Their role is to make layer contracts explicit and executable.

Examples:

- DF validator: graph/legal-op/access-path invariants
- Vec validator: axis and vector-semantics invariants
- Loop validator: execution-shape invariants

## Emitters

Emitters should be dumb.

They should:

- walk normalized IR
- emit target syntax
- handle small target-specific conventions

They should not:

- rediscover semantic meaning
- infer shapes
- repair incomplete lowering

If emitter logic becomes clever, the earlier IR layers are probably missing a
responsibility.

## Testing and Inspection

IR work should be verified by stage, not only end-to-end.

The inspection flow uses `golden_v2` (or `bin/kumi pp <repr> <schema>` for a
single schema):

```bash
bundle exec bin/kumi golden_v2 verify --repr frontend <schema>
bundle exec bin/kumi golden_v2 verify --repr df <schema>
bundle exec bin/kumi golden_v2 verify --repr vec <schema>
bundle exec bin/kumi golden_v2 verify --repr loop <schema>
bundle exec bin/kumi golden_v2 verify --repr codegen <schema>
```

This allows earlier IRs to be debugged even when later codegen is still being
refactored.

## Design Rule

Put changes in the earliest responsible layer.

- semantic bugs belong in DFIR / VecIR / LoopIR
- storage/materialization bugs belong in BufIR
- syntax-only bugs belong in emitters

That rule is one of the main safeguards against architecture drift.

