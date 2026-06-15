# Pass Conventions, Contracts, and Dedup — Design

**Date:** 2026-06-12
**Repo:** kumi-core, branched off `streaming-v2`
**Status:** Approved

## Problem

The compiler pipeline (analyzer passes + IR passes) has grown organically:

- `.rubocop.yml` excludes paths that no longer exist (`lib/kumi/analyzer/passes/**/*`,
  `lib/kumi/function_registry.rb`, `lib/kumi/types.rb`, `lib/kumi/runner.rb`), so
  rubocop reports 1,286 offenses in 218 files and is effectively unenforceable.
- Pass dependencies are implicit: ~25 state keys flow between ~24 analyzer passes,
  documented only as `# In:/# Out:` comments and runtime `get_state(..., required: true)`.
- Naming is inconsistent: most passes end in `Pass`, but 8 do not
  (`NameIndexer`, `InputCollector`, `DeclarationValidator`, `SemanticConstraintValidator`,
  `DependencyResolver`, `Toposorter`, `UnsatDetector`, `LoadInputCSE`).
- Boilerplate duplication: `DFValidatePass`/`VecValidatePass`/`LoopValidatePass` are the
  same ~15 lines three times; `Vec::LowerPass`/`Loop::LowerPass` likewise. Five passes
  hand-roll `case node when NAST::…` recursion despite NAST having an `accept` protocol.
  `PassManager#run` is a single ~120-line method interleaving checkpointing, debug,
  profiling, and error conversion.

Blast radius is internal only: nothing in kumi-play or kumi-parser references pass class
names; ~11 spec/doc files inside kumi-core do, plus dev-only env vars (`KUMI_RESUME_AT`,
`KUMI_STOP_AFTER`, `DEBUG_*`) derived from short class names.

## Design

Five layers, built and committed in order. Layers 1–2 are mergeable independently of 3–4.

### 1. Lint: fix and scope per-path

- Rewrite `.rubocop.yml`:
  - Delete all excludes pointing at nonexistent paths.
  - Scope relaxed Metrics cops (`MethodLength`, `AbcSize`, `CyclomaticComplexity`,
    `PerceivedComplexity`) to `lib/kumi/core/analyzer/passes/**/*` and
    `lib/kumi/ir/*/passes/**/*`. Stock limits elsewhere.
  - Keep existing style choices (double quotes, line length 140, no Documentation cop).
- Apply safe autocorrects (`rubocop -a`), verify the spec suite passes afterward.
- Generate `.rubocop_todo.yml` (`rubocop --auto-gen-config`) for remaining offenses so
  `bundle exec rubocop` exits green immediately: new code lints clean, legacy debt is
  enumerated for incremental burn-down.

### 2. Conventions doc: `docs/PASSES.md`

Codifies the rules:

- Every pass class name ends in `Pass`; file name ends in `_pass.rb`.
- Analyzer passes are `state → state` (`PassBase`, `run(errors)` returns `AnalysisState`).
  IR passes are `graph → graph` (`IR::Passes::Base`, `run(graph:, context:)` returns the
  graph). Never mix the two shapes; bridging happens only via the boundary adapters
  (layer 4).
- State contracts are declared with the `reads`/`writes` DSL (layer 3), never as
  `# In:/# Out:` comments.
- New acronym class names require a zeitwerk inflector entry in `lib/kumi.rb` and are
  discouraged.
- Inside `lib/`, only stdlib requires; zeitwerk owns `kumi/*` (exceptions: the files
  explicitly ignored in `lib/kumi.rb`).
- Env-var conventions: `DEBUG_<PASS_SHORT_NAME>=1`, `KUMI_RESUME_AT`/`KUMI_STOP_AFTER`
  take the pass short class name.

### 3. Declared state contracts

Class-level DSL on `PassBase`:

```ruby
class SNASTPass < PassBase
  reads  :nast_module, :input_table, :registry
  writes :snast_module
end
```

- `reads :key` — required input; auto-defines a memoized reader method (`nast_module`)
  that replaces the `get_state(:nast_module, required: true)` boilerplate.
- `optional_reads :key` — same, but `nil` when absent (covers e.g. `DFValidatePass`
  reading `:df_module_unoptimized`).
- `writes :key` — declares produced keys.
- Enforcement in `PassManager` (always on; key-level checks are cheap):
  - before run: all `reads` keys present in state, else fail with the pass name and key;
  - after run: new/changed top-level keys must be a subset of `writes`.
    Deep value diffing remains debug-only as today.
- Pipeline self-check spec: iterate `DEFAULT_PASSES`, `LOWERING_PASSES`, `TARGET_PASSES`
  and assert every `reads` key is produced by an earlier pass's `writes` or by the
  initial state (`:registry`, `:schema_digest`, analyzer opts). Pass ordering becomes
  machine-checked; the numbered comments in `analyzer.rb` are removed.
- All existing passes migrate to the DSL; `# In:/# Out:` comments are deleted.

### 4. Structural dedup

- **Boundary adapter factories** replacing five near-identical files:
  - `IRValidatePass.for(:vec_module, Kumi::IR::Vec::Validator)` → collapses
    `DFValidatePass`, `VecValidatePass`, `LoopValidatePass`. The DF variant's
    dual-module/`allow_fold` handling is parameterized.
  - `IRLowerPass.for(from: :df_module, to: :vec_module, module_class:, pipeline:)` →
    collapses `Vec::LowerPass`, `Loop::LowerPass`.
  - Factories return named `PassBase` subclasses with contracts declared, so debug env
    vars and `KUMI_RESUME_AT` short names keep working.
- **Shared NAST traversal**: add `children` (and `each_child`) to `NAST::Node`
  subclasses; rewrite the hand-rolled `case node when NAST::…` recursions in
  `ContractCheckerPass`, `NASTDimensionalAnalyzerPass`, `AttachAnchorsPass`,
  `AttachTerminalInfoPass`, and `LowerToIRV2Pass` to dispatch only on the node types
  they act on and default-recurse via the shared helper.
- **`PassManager#run` decomposition**: extract checkpointing, debug logging, and
  profiling into private instrumentation methods (or a small wrapper object) so the
  core loop is ~20 lines. Behavior identical.
- **Renames** (8 classes + files + the ~11 internal spec/doc references):
  `NameIndexerPass`, `InputCollectorPass`, `DeclarationValidatorPass`,
  `SemanticConstraintValidatorPass`, `DependencyResolverPass`, `ToposorterPass`,
  `UnsatDetectorPass`, `LoadInputCSEPass` (inflector entry updated accordingly).

### 5. Loading cleanup (folded into layer 4's commit)

Remove redundant `require "kumi/ir/df"` / `"kumi/ir/vec"` / `"kumi/ir/loop"` lines
inside `lib/` and the remaining internal `require_relative` stragglers where zeitwerk
already resolves the constant. Stdlib requires stay.

## Error handling

- Contract violations raise/fail through the existing `PassFailure`/`ExecutionResult`
  path with the offending pass name and key — no new error types.
- Rubocop todo ratchet means CI lint failures only ever point at newly introduced
  offenses.

## Testing

- Full spec suite green after every layer (each layer is a separate commit).
- New specs: contract DSL unit specs, pipeline self-check spec, NAST traversal specs.
- Golden tests unchanged — none of this touches codegen output.

## Out of scope

- Changing pass semantics, pass ordering, or codegen output.
- The `registry_v2` / functions subsystems.
- kumi-parser and kumi-play.
