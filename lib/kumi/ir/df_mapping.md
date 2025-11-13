# IR::DF → Loop IR Mapping

This note captures the functionality the new DF layer must model so it can lower
cleanly into the existing Loop IR (`lib/kumi/core/analyzer/passes/lir/lower_pass.rb`
and `lib/kumi/core/lir/**`). Today the pipeline jumps directly from SNAST to
loop-level instructions, so DF needs to re-express those behaviors in a
functional form while still carrying enough metadata to materialize structured
loops later.

## What Loop IR Does Today

Loop IR instructions span two categories:

1. **Dataflow nodes** – constants, declaration/input loads, tuple/object
   builders, kernel/import calls, selects, folds/reduces.
2. **Loop mechanics** – `LoopStart`/`LoopEnd`, accumulator declare/load/update,
   plus implicit control/side effects (e.g., `yield`) tied to loop depth.

The lowering pass also tracks per-axis execution context (open loops, element
registers, index registers, anchor input plans) and manages accumulator scopes.
This means DF must remember enough about axes, anchors, and reduction intents
before the loops exist.

## DF Representation Goals

DF should be “loop free” but still explicit about:

- **Axes / extents** – each node needs the axes it lives on so the Loop layer
  can open the right nests later (mirrors `meta[:stamp][:axes]` in SNAST).
- **Producers/consumers** – a graph of map/select/reduce/fold nodes with typed
  edges (dtype + axes), not imperative register mutations.
- **Access plans** – references to precomputed input plans / anchors so the Loop
  layer knows where to source collections.
- **Reduction intent** – differentiate element-wise folds vs. axis reductions,
  plus carry the reducer function id / over-axes.
- **Materialization hints** – e.g., whether tuples become structs/objects,
  whether a node should emit scalars vs. collections, or whether an op is pure.

## Mapping Responsibilities

| SNAST construct                        | DF node / attribute                                   | Loop IR emission                                                 |
|---------------------------------------|--------------------------------------------------------|------------------------------------------------------------------|
| `Const` / literals                    | `df.constant` node with dtype                          | `Build.constant`                                                 |
| `InputRef` (with key chain + axes)    | `df.input` node (captures plan id + axes)              | `Build.load_input` + nested `Build.load_field`                   |
| `Ref` to declaration                  | `df.decl_ref`                                          | `Build.load_declaration`                                         |
| `Call` (elementwise)                  | `df.map` / `df.apply` node, tracks fn id               | `Build.kernel_call`                                              |
| `Select`                              | `df.select` node (axes inherit LUB of branches)        | `Build.select`                                                   |
| `Reduce` (axis reduction)             | `df.reduce` node with `.over_axes` and reducer fn      | Loop open suffix axes + accumulator declare/accumulate/load      |
| `Fold` (tuple reduction)              | `df.fold` node, preserves axes                         | `Build.fold`                                                     |
| `Tuple` / `Hash` construction         | `df.make_tuple` / `df.make_object`                     | `Build.make_tuple` / `Build.make_object`                         |
| Loop-carried accumulators             | DF reduction metadata                                  | `LoopStart`/`LoopEnd`, `DeclareAccumulator`/`Accumulate`/`Load`   |
| Yield of declaration body             | DF function result                                     | `Build.yield` + implicit loop closure                            |

## Required Metadata on DF Nodes

- `axes`: ordered list of logical axes (same semantics as SNAST stamps).
- `dtype`: `Kumi::Core::Types::Type` describing the value shape (scalars, tuples,
  arrays, or full object types for imported schemas).
- `source`: reference to input plan or declaration (for loads).
- `function`: registry id for kernels/reductions/imports.
- `over_axes`: for reductions, denotes which axes collapse.
- `attributes`: freeform hash to carry things like object field names or tuple
  ordering.

### Input Types Matter

When targeting typed backends (C, LLVM, etc.) we must know not only the scalar
kind but the full structure of each input object (arrays of structs, nested
hashes, etc.). DF nodes that originate from inputs should therefore retain a
pointer to the relevant entry from `state[:input_table]`, which already carries:

- the logical axes for each input path,
- the declared dtype (currently symbols but ultimately `Kumi::Core::Types`),
- navigation steps / key chains needed to reach nested fields.

By preserving that typed input metadata in DF, later layers (Loop/Buf/Vec) can
emit precise structs in C without reverse-engineering types from raw field
accesses.

## DF→Loop Lowering Strategy

1. **Anchor discovery** – use node metadata (likely from `SnastFactory` tests or
   actual analyzer state) to resolve which input plan supplies each axis.
2. **Loop planning** – compute the set of axes required for each DF node,
   ensuring loops open in prefix order (mirrors `ensure_context_for!` and
   `open_suffix_loops!` in the current lowering pass).
3. **Instruction emission** – translate DF nodes in topological order to the
   imperative `Build.*` calls, using DF metadata for dtype, attrs, and loop
   structure.
4. **Accumulator synthesis** – for each `df.reduce`, auto-create accumulator
   names and wrap the `df.arg` in the proper loop context, emitting
   declare/accumulate/load instructions.

Keeping these responsibilities explicit in DF will make it a real “base” layer
for Loop IR: transformations (fusion, algebraic rewrites) can operate on DF
without worrying about low-level loop state, and lowering to the existing LIR
becomes a deterministic mechanical step.
