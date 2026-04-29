# VecIR Definition

VecIR is the vectorized IR that sits after DFIR. It preserves array semantics
without materializing loops, keeps axes/dtype metadata on every value, and is
optimized by a dedicated Vec pipeline (const-prop, GVN, axis canonicalization,
peephole simplification, stencil detection, DCE).

This document describes the object model, core ops, and invariants, and checks
their fit against current Kumi scenarios.

## Object Model

- **Module** (`Kumi::IR::Vec::Module`)
  - A named container of functions keyed by declaration name.
  - Produced by `Vec::Lower` and optimized by the Vec pipeline.

- **Function** (`Kumi::IR::Vec::Function`)
  - Name, parameters (currently unused), ordered blocks, return stamp.
  - In practice, a single entry block with a linear instruction list.

- **Block** (`Kumi::IR::Base::Block`)
  - Linear list of SSA-like instructions (no explicit control flow yet).

- **Instruction** (`Kumi::IR::Vec::Ops::Node`)
  - `opcode`, `result`, `inputs`, `attributes`, `metadata`.
  - `metadata` always includes `axes` and `dtype`.
  - `effects` are currently none (all ops are pure).

## Core Ops

Each op is a `Vec::Ops::*` node with `result`, `axes`, and `dtype`.

- `constant(value)`  
  Attributes: `value`.  
  Axes: `[]`. Dtype: literal type.

- `load_input(key, chain)`  
  Attributes: `key`, `chain`.  
  Axes/dtype: taken from input metadata.

- `load_field(object, field)`  
  Attributes: `field`.  
  Axes/dtype: same as `object`.

- `map(fn, args)`  
  Attributes: `fn` (kernel id).  
  Axes: shared axes of all args. Dtype: kernel result dtype.

- `select(cond, on_true, on_false)`  
  Axes: aligned across inputs. Dtype: same as value args.

- `axis_broadcast(value, from_axes, to_axes)`  
  Axes: `to_axes`. Dtype: same as value.

- `axis_shift(source, axis, offset, policy)`  
  Attributes: `axis`, `offset`, `policy` (`wrap|clamp|zero`).  
  Axes: unchanged. Dtype: same as source.

- `axis_index(axis)`  
  Produces the index vector for a given axis.  
  Axes: the axis itself.

- `reduce(fn, arg, over_axes)`  
  Attributes: `fn`, `over_axes`.  
  Axes: input axes minus `over_axes`. Dtype: reduction result dtype.

- `make_object(inputs, keys)`  
  Attributes: `keys`.  
  Axes: common axes of inputs (inputs are broadcast-aligned if needed).

## Invariants and Canonicalization

- Every instruction carries `axes` and `dtype` in metadata.
- `map` and `select` only operate on axis-aligned inputs.
- Scalars are lifted via `axis_broadcast` before vector ops.
- `reduce` removes `over_axes` from the result axes.
- `axis_shift` preserves axes, only shifts indexing.
- No tuples or array helpers at this stage:
  - DFIR `array_build` / `array_get` / `array_len` are canonicalized away.
  - DFIR `decl_ref` and `import_call` are inlined before VecIR.
- All ops are pure (no memory or IO effects).

## Fit to Current Scenarios

This op set matches the golden scenarios observed today:

- **Simple math**: `load_input` + `map` + `constant` + `make_object`.
- **Game of Life / stencils**: `axis_shift` + `map` + `axis_broadcast`; stencil
  detection tags clustered `axis_shift` patterns for later lowering.
- **Reductions**: `reduce` over explicit axes with kernel identities defined in
  the registry.
- **Schema imports**: handled in DFIR (`ImportInlining`), so VecIR stays local.
- **Nested objects**: `make_object` with explicit keys.

The current VecIR op set is sufficient for these cases, provided the DFIR
pipeline has already performed inlining and tuple/array canonicalization.

## Notes for Backends

VecIR is designed to lower cleanly into a loop materialization layer (LoopIR/LIR)
for Ruby/JS codegen. A future BufIR can sit between VecIR and LoopIR for targets
that need explicit allocation and lifetime control.
