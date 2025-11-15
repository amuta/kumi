# Kumi::IR Scaffold

This directory hosts shared intermediate-representation layers that sit between SNAST
and the existing LIR/codegen pipeline. The current goal is to provide explicit
types with stable interfaces so that lowering passes can target different IR
families without duplicating structural code.

## Layers

- **Base** – Common instruction, block, function, module, and builder classes.
  They capture shared behaviors (side-effect tracking, metadata, structural
  equality helpers) and are intended to be subclassed by concrete IRs.
- **DF (Array/Functional IR)** – Future lowering target directly from SNAST.
  Represents map/reduce/scan style graphs prior to loop materialization.
- **Loop** – Structured loops, matching today’s LIR semantics. Builders here
  will eventually replace the current `Kumi::Core::LIR::Build` helpers.
- **Buf** – Bufferized form that makes allocations, lifetimes, and ABI-visible
  objects explicit.
- **Vec** – Vectorized representation where explicit widths/masks are tracked
  before lowering to target ISAs.

Each layer exposes a `Module`, `Function`, `Instruction`, and `Builder` class so
passes can be written against a well-defined surface area. DF graphs are now
materialized during analysis (`LowerToDFIRPass`), and `Loop::Module.from_dfir`
reuses that graph to build the LoopIR equivalent before feeding the legacy LIR
stack. Those modules are kept in analysis state (`state[:df_module]`,
`state[:loop_module]`) so downstream passes and tooling can inspect them without
rerunning lowerings.

See `df_definition.md` for the instruction set and invariants we expect,
`df_mapping.md` for guidance on mapping SNAST→Loop IR, and `df_examples.md` for
concrete scenarios.

LoopIR roadmap lives in `loop_plan.md`, which outlines how DF graphs will be
lowered into structured loops, accumulators, and buffer-aware passes. The loop
pipeline currently contains a placeholder pass list wired through
`Kumi::IR::Loop::Pipeline`, making it easy to incrementally port optimizations
from today’s LIR stack.

Pretty printer commands are available for both layers:

- `kumi-dev pretty dfir` / `dfir_optimized` – DF graphs before/after the DF
  pipeline.
- `kumi-dev pretty loopir` – LoopIR emitted by `LoopLowerPass`.

## Test Helpers

Specs can fabricate IR inputs without running the entire analyzer pipeline by
using helpers under `Kumi::IR::Testing`. The primary entry point today is
`Kumi::IR::Testing::SnastFactory`, which exposes lightweight builders for
SNAST nodes and declarations:

```ruby
snast = Kumi::IR::Testing::SnastFactory.build do |b|
  b.declaration(:total_payroll, axes: %i[departments], dtype: :integer) do
    Kumi::IR::Testing::SnastFactory.const(0, dtype: :integer)
  end
end
```

RSpec suites get additional conveniences via `spec/support/ir_helpers.rb`,
which aliases the factory (`snast_factory`), provides `build_snast_module`,
and exposes helper constructors for DF graphs/builders. Include that helper
in custom test harnesses if you need the same shortcuts outside of RSpec.
