# Kumi Compiler Architecture

Kumi compiles schemas through a series of explicit semantic layers. Each layer
owns one kind of transformation, invariants are validated at layer boundaries,
and the backends emit syntax from fully normalized IR — never meaning from
partially-lowered IR.

## Pipeline

```text
Schema source (.kumi text or Ruby DSL)
  -> AST          parser output
  -> NAST         normalized AST
  -> SNAST        semantic AST with dimensional/type stamps
  -> DFIR         dataflow graph; access paths, imports, structural cleanup
  -> VecIR        axis-aware value semantics; every value stamped axes+dtype
  -> LoopIR       explicit execution structure: loops, accumulators, reads
  -> Emitters     Ruby / JavaScript serialization
```

The analyzer (`lib/kumi/analyzer.rb`) drives this as three pass groups:

- `DEFAULT_PASSES` — name indexing, imports, input collection, validation,
  dependency resolution, topo ordering, input access planning
- `LOWERING_PASSES` — NAST → SNAST → DFIR → VecIR → LoopIR, with a validator
  pass after each IR boundary
- `TARGET_PASSES` — `Codegen::LoopRubyPass` and `Codegen::LoopJsPass`, which
  serialize LoopIR

## Layer Responsibilities

### Frontend: AST, NAST, SNAST

Source-language normalization and semantic preparation.

- **AST** — parser output, close to source shape
- **NAST** — normalized form, removes frontend irregularity; constant folding
- **SNAST** — carries dimensional and type metadata, explicit enough to lower

Unsatisfiable-constraint detection and the output/input form schemas are
derived at this stage.

### DFIR

The first graph-shaped semantic layer.

- lowers SNAST into per-declaration dataflow functions
- normalizes input traversal and access paths against the input plans
- inlines declaration references and **schema imports** (callee bodies are
  spliced in; axis names and plan references are canonicalized to the
  caller's input plans at this boundary)
- canonicalizes tuples/objects, runs CSE, dedup, and broadcast cleanup

Bugs about input access, import behavior, or graph structure belong here.

### VecIR

Pure, declarative, axis-aware value semantics.

- every value is stamped with `axes` (named, ordered) and `dtype`
- broadcasts, shifts, indices, maps, selects, and reductions are explicit ops
- deterministic vector-level rewrites (GVN, canonicalization)
- no execution, storage, or target concerns

See [lib/kumi/ir/vec_definition.md](../lib/kumi/ir/vec_definition.md).

### LoopIR

The execution layer. Lowering from VecIR materializes:

- loop nests (`loop_start`/`loop_end`) over axis carrier arrays
- reductions as `acc_init`/`acc_step`/`acc_load`
- `axis_index` as loop index registers; `axis_shift` as policy-explicit
  shifted reads
- materialization (`array_init`/`array_push`/`index_read`) for values that
  cross loop boundaries

After LoopIR, emitters never infer axes, rediscover broadcasts, or branch on
rank. If a backend still needs vector semantics to emit code, LoopIR is not
finished.

See [lib/kumi/ir/loop_definition.md](../lib/kumi/ir/loop_definition.md).

### BufIR

A reserved boundary for storage concerns (allocation, lifetimes, layout).
LoopIR currently stays a pure execution layer and emitters serialize it
directly, so BufIR remains a stub. It becomes a real phase only if LoopIR
starts absorbing storage policy or emitters need layout knowledge.

### Emitters

Mechanical serializers (`Codegen::Loop::Ruby::Emitter`,
`Codegen::Loop::Js::Emitter`). Every LoopIR opcode maps to a fixed syntax
shape; emitters own naming, literal formatting, and kernel
inlining/helper emission — nothing semantic.

The architecture is healthy when emitter code is boring.

## Boundary Validators

Each IR boundary ends with a validator pass — the executable form of the
layer contract, not optional diagnostics:

- **`DFValidatePass`** — legal op families, access-path rules, root-only
  `load_input`, object/tuple sanity
- **`VecValidatePass`** — axes/dtype present on every value, broadcast and
  reduction shape rules
- **`LoopValidatePass`** — only execution opcodes, balanced loops,
  defs-before-use, defined returns

Validator specs include negative cases for illegal states, not only golden
snapshots of successful pipelines.

## Ownership Rule

When deciding where a fix belongs:

- meaning, traversal, axes, broadcast, or reduction semantics → DFIR / VecIR /
  LoopIR
- materialization, layout, ownership, temporary storage → BufIR
- emitted target syntax only → the emitter

If a backend patch compensates for an earlier semantic bug, it is in the
wrong place.

## Verification

Verification is staged. Each layer can be inspected and verified without
running the later ones:

```bash
bundle exec bin/kumi pp <repr> <schema.kumi>          # print one layer
bundle exec bin/kumi golden_v2 verify --repr <group>  # snapshot-check a layer
bundle exec bin/kumi golden test                      # runtime ground truth
```

Repr groups: `frontend`, `df`, `vec`, `loop`, `codegen`. Golden failures
identify which layer regressed, not just that "something failed later".

See [GOLDEN_TESTS.md](GOLDEN_TESTS.md).
