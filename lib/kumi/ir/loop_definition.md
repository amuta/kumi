# LoopIR Definition

LoopIR is the execution-materialization layer between VecIR and codegen. It
turns axis-aware vector semantics into explicit loops, accumulators, and
materialized arrays so that emitters can serialize it one opcode at a time
without inferring shapes, axes, or reduction behavior.

## Object Model

- **Module** (`Kumi::IR::Loop::Module`) — functions keyed by declaration name,
  produced by `Loop::Lower.new(vec_module:, context:)`.
- **Function** (`Kumi::IR::Loop::Function`) — single entry block plus
  `return_reg`, the register holding the declaration's final value.
- Instructions are flat; loop structure is expressed by balanced
  `loop_start` / `loop_end` markers.

`Loop::Lower` requires two context entries:

- `input_plans` — `precomputed_plan_by_fqn`, the access-planner table that maps
  input FQNs to navigation steps. It supplies the carrier array for every axis
  and the property/element steps of each load chain.
- `registry` — used to resolve reduction identities for `acc_init`.

## Core Ops

Scalar/value ops (one Ruby/JS expression each):

- `constant(value)`
- `load_input(key)` — root input key only
- `load_field(object, field)` — one property read off a concrete object
- `kernel_call(fn, args)` — element-level kernel application
- `select(cond, on_true, on_false)`
- `make_object(inputs, keys)` — tuple (`_0.._n` keys) or hash
- `ref(value)` — register alias

Execution structure:

- `loop_start(source, axis, index)` — iterates a carrier array; defines the
  element register (result) and the index register (attribute)
- `loop_end(axis)`
- `array_init` / `array_push(array, value)` — collect values that escape their
  defining loop
- `array_len(array)` / `index_read(array, index)`
- `shift_read(array, index, length, offset, policy)` — reads
  `array[index - offset]` under `wrap` or `clamp` policy
- `shift_in_bounds(index, length, offset)` — bounds predicate used to lower the
  `zero` shift policy as `select(in_bounds, value, fill)`
- `acc_init(fn, init, nil_init)` / `acc_step(acc, value, fn, nil_init)` /
  `acc_load(acc)` — reduction execution structure; `nil_init` marks reducers
  without an identity (min/max), which seed from the first element

## Lowering Contract

Input (VecIR after `VecValidatePass`):

- SSA registers, every value stamped with axes and dtype
- load chains follow the DF access contract (root `load_input`, one
  `load_field` per remaining segment)
- axis names are canonical: every stamped axis matches the axis name minted
  by the caller's input plans (DFIR `ImportInlining` rewrites callee-named
  axes at the inlining boundary), so lowering resolves carriers from the
  plans alone
- `reduce` over_axes are an innermost suffix of the argument axes

Guarantees on output (enforced by `Loop::Validator`):

- only the opcodes listed above; no `map`, `axis_broadcast`, `axis_shift`,
  `axis_index`, or `reduce` survive
- loops are balanced and registers are defined before use
- every function has a defined `return_reg`

How VecIR semantics are materialized:

- **Broadcasts** are erased: a value stamped with a prefix of the open axes is
  read directly as a live local.
- **`axis_index`** becomes the index register of the open loop for that axis.
- **`axis_shift`** becomes a `shift_read` against a fully collected array (the
  source's loops are closed first) or against the input carrier for lazy load
  chains; `zero` policy adds `shift_in_bounds` + `select`.
- **Reductions** place `acc_init` before the first reduced loop, `acc_step` in
  the innermost body, and `acc_load` after the reduced loops close.
- **Escaping vectors** (values used outside their defining loop instance, and
  vector return values) are collected with `array_init`/`array_push` and read
  back with `index_read`.
- **Load chains** are never materialized; they re-read input fields at each use
  site by walking the input plan against the open loops.

## Notes for Emitters

Emitters serialize each opcode to a fixed syntax shape and track indentation
for `loop_start`/`loop_end`. They resolve kernel inline templates from the
registry but make no semantic decisions; if an emitter needs to branch on axes
or rank, the missing logic belongs in `Loop::Lower`.
