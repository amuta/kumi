# Kumi::IR Scaffold

This directory hosts shared intermediate-representation layers that sit between SNAST
and the existing LIR/codegen pipeline. The current goal is to provide explicit
types with stable interfaces so that lowering passes can target different IR
families without duplicating structural code.

## Layers

- **Base** – Common instruction, block, function, module, and builder classes.
  They capture shared behaviors (side-effect tracking, metadata, structural
  equality helpers) and are intended to be subclassed by concrete IRs.
- **DF (Array/Functional IR)** – Lowering target directly from SNAST. Represents
  map/reduce/scan style graphs prior to loop materialization. The DF pipeline
  rewrites tuple helpers (`array_build + fold` → chained `map`s, scalar tuples →
  `make_object`) and enforces axis discipline before Vec gets involved.
- **Loop** – (Removed for now.) The structured-loop layer will return once VecIR
  and BufIR own the vector/buffer stages.
- **Buf** – Bufferized form that makes allocations, lifetimes, and ABI-visible
  objects explicit.
- **Vec** – Vectorized representation with axis-clean instructions, no tuples,
  and an optimization pipeline (const-prop, GVN, axis canonicalization,
  peephole algebra, stencil tagging, DCE) plus an analyzer pass that stores the
  optimized Vec module alongside DFIR.

Each layer exposes a `Module`, `Function`, `Instruction`, and `Builder` class so
passes can be written against a well-defined surface area. DF graphs are now
materialized during analysis (`LowerToDFIRPass`), Vec graphs via the new
`Passes::Vec::LowerPass`, and both DF/Vec representations can be pretty-printed
from goldens (DF: `dfir.txt`, `dfir_optimized.txt`; Vec: `vecir.txt`).

See `df_definition.md` for the instruction set and invariants we expect,
`df_mapping.md` for guidance on mapping SNAST→Loop IR, and `df_examples.md` for
concrete scenarios.

Pretty printer commands are available for DFIR/VecIR layers:

- `kumi-dev pretty dfir` / `dfir_optimized` – DF graphs before/after the DF
  pipeline.
- `kumi-dev pretty vecir` – Vec graphs after DF lowering + Vec pipeline.

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
