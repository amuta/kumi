# Compiler Pass Conventions

These rules are enforced by `spec/kumi/analyzer_pipeline_contract_spec.rb`,
`PassManager` contract checks, and RuboCop. Change the enforcement when you
change a rule.

## Naming

- Every pass class name ends in `Pass`; its file name ends in `_pass.rb`.
- New acronyms in class names require a zeitwerk inflector entry in
  `lib/kumi.rb` and are discouraged — prefer plain words.

## Two pass shapes, never mixed

- **Analyzer passes** (`lib/kumi/core/analyzer/passes/`): subclass
  `Passes::PassBase`. `run(errors)` takes an error accumulator and returns an
  `AnalysisState`. State is immutable; produce new state with `state.with`.
- **IR passes** (`lib/kumi/ir/*/passes/`): subclass `Kumi::IR::Passes::Base`.
  `run(graph:, context:)` returns a graph; compose with `IR::Passes::Pipeline`.
- Bridging happens only through the boundary adapters `IRValidatePass` and
  `IRLowerPass` — never call an IR pipeline ad hoc from an analyzer pass.

## State contracts

Every analyzer pass declares what it touches, at the top of the class body:

    class SNASTPass < PassBase
      reads  :nast_module, :metadata_table, :registry
      writes :snast_module
    end

- `reads` — required keys; fails fast in `PassManager` if absent. Also defines
  a reader method per key.
- `optional_reads` — keys that may be absent; reader returns `nil`.
- `writes` — every key the pass adds or replaces. A pass that produces no
  state declares bare `writes` (no arguments) so the contract is still
  explicit. `PassManager` rejects any undeclared write.
- `# In:` / `# Out:` comments are banned — the DSL is the single source of
  truth, and `spec/kumi/analyzer_pipeline_contract_spec.rb` checks that every
  pipeline pass declares a contract and that pass ordering satisfies all reads.
- Passes that annotate IR/NAST nodes in place (e.g. `AttachTerminalInfoPass`)
  declare bare `writes`; keep such in-place mutation limited to node `meta` /
  annotation fields, never structure.

## Error reporting

One channel per logical error — never report AND raise the same problem (that
surfaces it twice, once via the accumulator and once via PassManager's exception
capture, which also leaks internal file paths).

- **User-facing errors** (the schema is wrong): record them in the `errors`
  accumulator passed to `run`, with a real `location:` (pass the node's `loc`,
  never interpolate it into the message string). Use `report(errors, msg, node:)`
  to keep going and collect more, or `halt_pass!(errors, msg, node:)` to record
  one and stop the pass cleanly. A halted/erroring pass fails because `errors`
  is non-empty — no exception needed.
- **Internal invariants** ("can't happen" — a violated assumption, not bad user
  input): `raise Kumi::Core::Errors::CompilerBug, "..."`. It is framed as a bug
  to report and is never presented to users as if they wrote bad input.
- Do not raise `SemanticError`/`TypeError` directly from a pass for user errors;
  route them through the accumulator so they are located and deduplicated.

## Loading

- zeitwerk owns everything under `lib/kumi/`. Inside `lib/`, only require
  stdlib (`require "json"` etc.) — never `require "kumi/..."` for autoloadable
  constants. Exceptions are the files explicitly ignored in `lib/kumi.rb`.

## Debug and checkpoint env vars

- `DEBUG_<SHORT_NAME>=1` enables per-pass debug output; the short name is the
  class name minus the `Pass` suffix, underscored (`SNASTPass` → `DEBUG_SNAST`).
- `KUMI_RESUME_AT` / `KUMI_STOP_AFTER` take the pass short class name
  (e.g. `SNASTPass`).
- `KUMI_DEBUG_REQUIRE_FROZEN=1` makes `PassManager` assert state values are
  frozen after each pass (debug mode only).
