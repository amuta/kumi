# DFIR Definition

Target: a functional, SSA-style graph where every node is pure, fully typed,
and memory-free. DFIR captures array algebra semantics before loops or buffers
appear. This doc enumerates the instruction families and invariants we want for
the new IR.

## Core Principles

- **SSA values** – each instruction produces at most one result; references are
  by symbolic registers.
- **Total typing** – every result has a `Kumi::Core::Types::Type` (scalars,
  tuples, arrays, objects). Containers keep their axis metadata.
- **Pure kernels only** – DF nodes describe computations; no side effects,
  memory allocation, or loop control.
- **No implicit memory** – inputs/objects are logical values. BufIR performs
  bufferization later.

## Instruction Families

### Structural Access (shape-preserving)

Operate on objects/arrays without changing axes:

- `Input(path)` – fetch a top-level container.
- `ObjectGet(obj, key)` – access a field from an object/struct/hash.
- `ArrayBuild(elements)` – construct literal arrays/tuples with explicit size.
- `ArrayGet(array, index, oob)` – gather an element with wrap/clamp/zero policy.
- `ArrayLen(array)` – scalar length of an array along its last axis.
- `AxisIndex(axis)` – current integer index for a given axis (for IndexRef support).
- `AxisShift(source, axis, offset, policy)` – stencil shift/roll operations with explicit axis/policy metadata.
- `AxisBroadcast(value, from_axes, to_axes)` – replicate values across additional axes for broadcast semantics.
- `Fold(fn, arg)` – elementwise tuple/struct fold (no axis collapse).
- `ImportCall(fn_name, module, args)` – pure imported-schema invocation.
- `Repack` – rebuild objects (optional helper for updates).

Invariants: results retain container dtype/axes; keys are symbolic (no integer
indexing).

### Element Access (shape-reducing)

Operate on arrays and produce element values at the current axes:

- `ArrayGet(array, index, oob:)` – gather an element.
- `ArrayLen(array)` – scalar length.

Attributes: `oob` policy (`:wrap`, `:clamp`, `:zero`); this replaces ad-hoc
modulo/clamp arithmetic.

Invariants: inputs must be arrays; indices are integers; result axes equal the
active loop axes at the access site.

### Functional Kernels

Pure computations over SSA values:

- `Map(fn, args, axes)` – elementwise kernel invocation.
- `Select(cond, true_value, false_value)` – predicate combine.
- `Reduce(fn, arg, axes, over_axes)` – axis reduction with explicit reducer
  id.
- `Fold(fn, tuple_arg)` – elementwise tuple fold (no axis collapse).
- `Import(fn_name, module, args)` – imported schema call, still pure.
- Planned axis ops: `Broadcast`, `AxisReshape`, `AxisZip` to manage scope.

### Composition / References

- `DeclRef(name)` – reference another DF declaration result.
- Optional `Let(name, value)` for aliasing or debugging.

## Metadata

Every instruction carries:

- `axes` – ordered axes the value varies over.
- `dtype` – type object.
- `attributes` – op-specific data (function id, object keys, tuple arity,
  `oob` policy, input plan id, etc.).
- `source_plan` – optional reference to the analyzer input plan for structural
  accesses.

## Verifier Rules

1. Structural ops produce non-scalar containers; element ops consume arrays and
   integer indices.
2. `ArrayLen` only accepts arrays.
3. `ArrayGet` must cite a valid `oob` policy.
4. Axes on results must align with operands and analyzer context.
5. No instruction emits side effects or loops; control stays implicit via axes.

## Lowering Cheatsheet (from SNAST)

- `input.rows` → `Input("rows")`.
- `hash[:k]` → `ObjectGet(hash, "k")`.
- `arr[i]` → `ArrayGet(arr, i, oob: policy)`.
- `arr.length` → `ArrayLen(arr)`.
- `Call :core.add` → `Map(fn: :"core.add", args)`.
- `Select` stays `Select`.
- `Reduce` keeps reducer fn plus `over_axes`.
- `Ref decl` → `DeclRef(:decl)`.
- Tuple/object assembly uses `MakeTuple` / `MakeObject` instructions.

Clear boundaries here keep DF a true functional IR while still encoding
everything the Loop/Buf layers need to materialize structured loops later.
