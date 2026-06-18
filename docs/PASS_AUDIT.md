# Analyzer Pass Audit — Findings & Plan

Audit of `lib/kumi/core/analyzer/` (≈45 passes + machinery). Baseline: 959 examples,
0 failures, 50/50 goldens. Each finding is evidence-backed; severity is impact × reach.

The framework itself (`PassManager`, `AnalysisState`, contract DSL in `PassBase`,
`docs/PASSES.md`, the contract spec) is **good** — immutable state, declared reads/writes,
ordering enforcement, per-pass budget, checkpoint/resume. The problems are in how passes
*report errors* and a few localized hygiene issues. Most value is in error reporting.

---

> **STATUS (2026-06-18): F1, F2, F3, F4, F5 DONE + location rendering unified.**
> Added `Errors::UnsupportedFeature` (a valid construct the backend can't emit) alongside
> `CompilerBug`. Converted the codegen "does not support opcode/shift-policy/inline" raises
> (Ruby + JS emitters) to `UnsupportedFeature`; converted the compiler accessor invariants
> ("unknown accessor mode/operation") and the binder/macro_expander/pass_manager contract
> invariants to `CompilerBug`. Unified all source-location rendering on one `file:line:col`
> format (Location#to_s is the single authority; ErrorEntry/LocatedError/PassFailure/SourceFrame
> all delegate; killed the double-location). Gated by error_reporting_spec + error_handling_spec.
> DISCOVERY: `compiler/access_planner.rb` (v1, 258 LOC) is DEAD — superseded by
> `AccessPlannerV2`, zero live refs, no specs; its 7 ArgumentError invariants were left
> untouched pending deletion (separate cleanup). Remaining: **F6**, **F7**, +delete dead v1.
> 969 specs, 50/50 goldens.
>
> **STATUS (2026-06-18): F1, F2, F4, F5 DONE.** A type mismatch now surfaces as exactly
> one located error with no internal leaks (was 3). Added `Errors::CompilerBug`; `PassBase`
> gained `report`/`halt_pass!` (via a `catch(HALT)` in PassManager) and lost the broken
> `error` footgun; removed the duplicate re-append in `analyzer.rb`; swept
> `nast_dimensional_analyzer_pass` + `snast_pass` + `ir_execution_schedule_pass` and the
> invariant lookups in `attach_anchors`/`attach_terminal_info`/`input_collector`/
> `precompute_access_paths` to CompilerBug. Rule documented in `PASSES.md`. Gated by
> `spec/kumi/core/analyzer/error_reporting_spec.rb`. Remaining: **F3** (codegen "does not
> support" capability raises — 7 sites), **F6**, **F7**. 965 specs, 50/50 goldens.

## F1 — Errors triple-report; located error buried under internal leaks  ★★★ (highest impact)

**Evidence:** a single `add(string, string)` type mismatch surfaces THREE times to the user:

```
at s.kumi line=5 column=18: add(string, string) - type mismatch        <- good, located
Error in Analysis Pass(NASTDimensionalAnalyzerPass) at .../nast_dimensional_analyzer_pass.rb:119: ... type mismatch
Error in Analysis Pass(NASTDimensionalAnalyzerPass) at .../nast_dimensional_analyzer_pass.rb:119: ... type mismatch
```

**Root cause:** `NASTDimensionalAnalyzerPass` (and others) do BOTH
`report_type_error(errors, ...)` (accumulate, located) AND immediately `raise TypeError`
(`nast_dimensional_analyzer_pass.rb:108-128`, `:151`). `PassManager#capture_exception`
(`pass_manager.rb:148`) catches the raise and adds a SECOND error built from the backtrace
head (`Error in Analysis Pass(X) at <file:line>: …`) — leaking compiler internals + file
paths to the user. The duplication-to-three comes from the raise being captured and the
located error also flowing through.

**Fix:** pick ONE reporting channel per logical error. For user-facing errors: accumulate
via `report_*` and `return state` (or `throw`/sentinel to stop the pass) — do NOT also raise.
`capture_exception` should be reserved for genuine bugs (unexpected exceptions), and its
message should not be presented as a user error alongside located ones. Dedup errors before
`handle_analysis_errors` formats them.

## F2 — Location passed in the message string, not the structured field  ★★★

**Evidence:** `snast_pass.rb:94` —
`raise SemanticError, "select mask axes ... at: #{n.loc}"`. The location is interpolated
into the text instead of `SemanticError.new(msg, n.loc)`, so `SourceFrame`/`PassFailure`
can't render a code frame and the coordinate can't be deduped.

**Also:** 14 sites do `raise Kumi::Core::Errors::SemanticError, "msg"` / `TypeError, "msg"`
with NO location arg at all (`snast_pass.rb:102,133,140,196,209`,
`nast_dimensional_analyzer_pass.rb:128,151,179,183,211,215,396`, `ir_execution_schedule_pass.rb:23,54`).
Each user-reachable one should pass the node's `loc`.

**Fix:** every `LocatedError` raised from a user-reachable condition passes `node.loc` as the
second arg; never interpolate location into the message.

## F3 — Bare `raise "string"` (RuntimeError) for both invariants and user errors  ★★

**Evidence (14 sites):** `input_collector_pass.rb:120`, `attach_anchors_pass.rb:60,70,90`,
`attach_terminal_info_pass.rb:36`, `snast_pass.rb:102`, `nast_dimensional_analyzer_pass.rb:69,344`,
`precompute_access_paths_pass.rb:76` (`raise ArgumentError, "order"` — opaque), the three
codegen emitters (`"… codegen does not support …"`).

Two distinct intents are conflated:
- **Internal invariants** ("unknown parent container", "no anchor for axes") — "can't happen"
  bugs. These SHOULD raise, but as a dedicated `Kumi::Core::Errors::CompilerBug` (new) so
  they're never mistaken for user errors and carry a "please report" framing.
- **Capability limits** (codegen "does not support opcode X") — these are real, expected
  conditions; should be a typed error with the offending opcode/policy, not a bare string.

**Fix:** introduce `CompilerBug < Error` for invariants; convert capability raises to a typed
`Errors::UnsupportedFeature` (or reuse `CompilationError`) with structured context.

## F4 — `PassBase#error` helper is a footgun (reads unset `@errors`)  ★★

**Evidence:** `pass_base.rb:113-116` — `def error(...) add_error(@errors, ...)`. `@errors`
is never assigned by `PassBase`; `run(errors)` passes the accumulator as an ARGUMENT. Only
`snast_pass.rb:17` sets `@errors` manually (then ignores it and raises anyway). No other pass
calls `error`. So the base helper silently pushes to `nil` for any pass that uses it without
the undocumented `@errors =` ritual.

**Fix:** either (a) remove the broken `error`/`add_error` instance helpers from `PassBase` and
standardize on the `ErrorReporting` mixin's `report_*(errors, …)` (explicit accumulator), or
(b) make `PassBase#run` store `@errors = errors` via a `super`/template method so `error`
works. Prefer (a) — explicit accumulator threading matches the rest of the codebase.

## F5 — Two reporting idioms split the pipeline in half  ★★

**Evidence:** ~15 passes take `run(errors)` and accumulate; ~14 take `run(_errors)` and only
`raise`. The accumulator path enables multi-error reporting + located `PassFailure`; the raise
path gives single-error, degraded `capture_exception` output. The split is not by intent
(validation vs lowering) — it's incidental.

**Fix:** document the rule in `PASSES.md` ("user-reachable errors accumulate; invariants
raise `CompilerBug`"), then bring the raise-only validators in line. Lowering passes that only
hit invariants legitimately keep `_errors`.

## F6 — `FormalConstraintPropagator` misfiled in `passes/`, breaks naming convention  ★

**Evidence:** `passes/formal_constraint_propagator.rb` — class `FormalConstraintPropagator`,
no `Pass` suffix, not a `PassBase`, not in any pipeline list. It's a COLLABORATOR used by
`UnsatDetectorPass:19`. It also carries the banned `# RESPONSIBILITY:/DEPENDENCIES:/INTERFACE:`
header comment (cousin of the `# In:/# Out:` ban in PASSES.md).

**Fix:** move it to `lib/kumi/core/analyzer/` (alongside `binder.rb`, `folder.rb`,
`constant_evaluator.rb`) so `passes/` contains only passes; drop the header comment.

## F7 — Codegen emitters duplicate structure (JS 410 / Ruby 212 LOC)  ★ (lower priority, higher risk)

**Evidence:** `codegen/loop/js/emitter.rb` and `codegen/loop/ruby/emitter.rb` share a parallel
method skeleton (`emit_instruction`, `emit_function`, `emit_acc_step`, `emit_shift_read`,
`apply_inline`, `kernel_expr`, `format_literal`, `format_object`, `tuple_keys?`, `reg`) and the
same opcode-dispatch + "does not support" raise pattern, but emit different target syntax.

**Assessment:** real duplication, but target languages legitimately diverge; over-abstraction
here is a known trap. Recommend a SMALL shared base (opcode dispatch table + the unsupported-
opcode raise via F3's typed error + register/scratch naming), NOT a unified emitter. Defer
until F1–F5 land; treat as opportunistic.

## F8 — Two error modules with overlapping names  ★ (note, not necessarily a change)

`Core::ErrorReporting` (instance mixin: `report_*`, `raise_*`) vs `Core::ErrorReporter`
(module: `create_error`, `add_error`, `raise_error`, `ErrorEntry`). The split is defensible
(mixin vs factory) but the near-identical names invite confusion. Consider renaming the mixin
to `ErrorReportable` OR documenting the boundary in one place. Low priority.

---

## Plan (ordered by impact, each independently shippable & test-gated)

1. **F1+F2+F4+F5 together (the error-model fix)** — the highest-value, coherent change:
   - Add `CompilerBug` error class.
   - Establish the rule: user-reachable → accumulate located error + stop pass cleanly;
     invariant → raise `CompilerBug`. Document in `PASSES.md`.
   - Remove/fix the `PassBase#error` footgun.
   - Sweep `nast_dimensional_analyzer_pass` and `snast_pass` first (they cause the visible
     triple-report), then the rest of the raise-only validators.
   - Dedup errors in `analyzer.rb` before formatting.
   - **Net user-visible win:** one clean, located error instead of three with leaked internals.
   - Gate: new spec asserting the type-mismatch case yields exactly ONE located error with no
     `Error in Analysis Pass(...)` / no internal file paths.

2. **F3** — typed errors for invariants (`CompilerBug`) and capability limits
   (`UnsupportedFeature`/`CompilationError`) across passes + codegen emitters.

3. **F6** — relocate `FormalConstraintPropagator` out of `passes/`.

4. **F7** — opportunistic small shared codegen base (only after 1–3, only if low-risk).

5. **F8** — naming/doc clarification (optional).

Non-goals: rewriting the pass framework (it's sound), reordering the pipeline, touching IR
pass internals beyond error reporting.
