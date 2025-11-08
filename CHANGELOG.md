## [Unreleased]

## [0.0.33] – 2025-11-05
### Added
- **Peephole Optimization Helper:** `Kumi::Core::LIR::Peephole` plus specs for safer peephole transforms, inline Ruby clamp kernel, richer LIR dumps, and refreshed golden files
- **Import Diagnostics:** Clearer errors with available declaration hints when imports fail

### Changed
- Default `Kumi.configure.compilation_mode` now `:jit`; override via config or `KUMI_COMPILATION_MODE`
- Improved constant propagation output formatting for Ruby/JS codegen

## [0.0.32] – 2025-10-23
### Added
- **Schema Imports:** Reuse declarations from other schemas with `import :name, from: Module` syntax
- **Improved Import Errors:** Clearer messages with available declaration hints when imports fail
- Documentation: `docs/COMPOSED_SCHEMAS.md` and `docs/SCHEMA_IMPORTS.md`

## [0.0.31] – 2025-10-22
### Changed
- Documentation for schema imports in README and SYNTAX

## [0.0.30] – 2025-10-21
### Changed
- **Analyzer Refactoring:** PassManager now centralizes pass orchestration, replacing manual orchestration in Analyzer.run_analysis_passes
- Removed unused API surface: batch_update, .phases, with_phase, recoverable, phase_id methods

### Added
- ExecutionPhase, ExecutionResult, PassFailure for structured pass execution metadata
- PassManager handles checkpoint integration, debug logging, profiling, and error handling

### Fixed
- PassManager error handling now returns failures instead of raising, allowing proper error threshold checks

## [0.0.29] – 2025-10-21
### Changed
- Tests and development cleanup


## [0.0.28] – 2025-10-20
### Changed
- Error location formatting now uses explicit `line=` and `column=` keywords for clarity
- Location extraction prioritizes structured Location objects over message parsing
- Default file label changed from "(string)" to "schema" for better UX

### Fixed
- Removed redundant location information from error messages
- Parse error messages now properly format location details

## [0.0.27] – 2025-10-20
### Added
- Decimal type system for precise money/bignum calculations
- Conversion functions (to_decimal, to_integer, to_float, to_string)
- Automatic documentation generation system for IDE support
- VSCode extension with schema block detection

## [0.0.26] – 2025-10-17
### Added
- UNSAT detection via constraint propagation through operations
- Documentation for UNSAT detection in `docs/UNSAT_DETECTION.md`

### Changed
- Moved `UnsatDetector` to work over SNAST for full resolution context (axes/types)
- Refactored Typing system, added proper typing metadata on data/functions

## [0.0.25] – 2025-10-17
### Fixed
- Fix inlining bug caused by previous fix

## [0.0.24] – 2025-10-16
### Fixed
- Bug when inlining of declarations with multiple axis reductions.

## [0.0.23] – 2025-10-13
### Fixed
- OutputSchemaPass now excludes inline `:let` declarations from output_schema metadata, matching JS/Ruby codegen behavior

## [0.0.22] – 2025-10-13
### Removed
- Legacy analyzer passes and compiler components referencing old Registry and Runtime APIs
- Obsolete test files that depended on removed infrastructure

## [0.0.21] – 2025-10-13
Fix - update Gemfile.lock to current version

## [0.0.20] – 2025-10-13
Fix - Remove require of pry gem on runtime.

## [0.0.19] – 2025-10-13
### Added
- **Ruby & JavaScript Code Generation:** The compiler now directly generates clean, idiomatic Ruby and JavaScript (MJS) code from Kumi schemas, removing the need for a complex runtime interpreter.
- **IRv2:** A new, backend-agnostic intermediate representation (IR) that simplifies the compilation process and improves performance.
- **New Language Features:**
    - First-class `select` expressions for conditional logic.
    - `fold` expressions for reductions over tuples.
    - Hash expressions for creating and manipulating hash maps.
    - Tuple-based syntax for array literals.
- **Tooling:**
    - `InputFormSchemaPass` for generating minimal form schemas from Kumi files.
    - `OutputSchemaPass` for extracting output metadata.

### Changed
- **Compiler Architecture:** The compiler has been redesigned around the new IRv2 and code generation backend.
- **Syntax:** Array literals now use a tuple-based syntax `(1, 2, 3)` instead of `[1, 2, 3]`.

### Removed
- **Legacy Runtime:** The old, interpreter-based runtime and legacy FunctionRegistry have been removed in favor of direct code generation.
- **`align_to`:** The `align_to` operator has been removed from the language.

### Performance
- **Reduced Overhead:** By generating direct Ruby/JavaScript code, the runtime overhead of the interpreter is eliminated, resulting in significant performance improvements.
- **Optimizations:** New optimization passes, including loop fusion and inlining, have been added to the compiler.

## [0.0.18] – 2025-09-03
- Fixed bug missing updated Gemfile.lock

## [0.0.17] – 2025-09-03

### Removed  
- Reverted experimental function registry v2 implementation
- Cleaned up unused analyzer passes and simplified unsat detector logic

## [0.0.16] – 2025-08-22

### Performance
- Input accessor code generation replaces nested lambda chains with compiled Ruby methods
- Fix cache handling in Runtime - it was being recreated on updates
- Add early shortcut for Analyzer Passes.

## [0.0.15] – 2025-08-21
### Added
- (DX) Schema-aware VM profiling with multi-schema performance analysis
- DAG-based execution optimization with pre-computed dependency resolution

### Performance
- Reference operations eliminated as VM bottleneck via O(1) hash lookups

## [0.0.14] – 2025-08-21
### Added
- Text schema frontend with `.kumi` file format support
- `bin/kumi parse` command for schema analysis and golden file testing
- LoadInputCSE optimization pass to eliminate redundant load operations
- Runtime accessor caching with precise field-based invalidation
- VM profiler with wall time, CPU time, and cache hit rate analysis
- Structured analyzer debug system with state inspection
- Checkpoint system for capturing and comparing analyzer states
- State serialization (StateSerde) for golden testing and regression detection
- Debug object printers with configurable truncation
- Multi-run averaging for stable performance benchmarking

### Fixed
- VM targeting for `__vec` twin declarations that were failing to resolve
- Demand-driven reference resolution with proper name indexing and cycle detection
- Accessor cache invalidation now uses precise field dependencies instead of clearing all caches
- StateSerde JSON serialization issues with frozen hashes, Sets, and Symbols

### Performance
- 14x improvement on update-heavy workloads (1.88k → 26.88k iterations/second)
- 30-40% reduction in IR module size for schemas with repeated field access
- Eliminated load_input performance bottleneck that was consuming ~99% of execution time
- Optional caching system (enabled via KUMI_VM_CACHE=1) for performance-critical scenarios

## [0.0.13] – 2025-08-14
### Added
- Runtime performance optimizations for interpreter execution
- Input load deduplication to cache loaded input values and avoid redundant operations
- Constant folding optimization to evaluate literal expressions during compilation
- Accessor memoization with proper cache isolation per input context
- Selective cache invalidation for incremental updates

### Fixed
- Cache isolation between different input contexts preventing cross-context pollution
- Cascade mutual exclusion tests now pass correctly with proper trait evaluation
- Incremental update performance with targeted cache clearing

## [0.0.12] – 2025-08-14
### Added
- Hash objects input declarations with `hash :field do ... end` syntax
- Complete hash object integration with arrays, nesting, and broadcasting

## [0.0.11] – 2025-08-13
### Added
- Intermediate Representation (IR) and slot-based VM interpreter.
- Scope-aware vector semantics (alignment, lift, hierarchical indices).
- Debug tooling: IR dump, VM/lowering traces via DEBUG_* flags.

### Changed
- Analyzer now lowers to IR via `LowerToIRPass`.
- Access modes: `:read`, `:ravel`, `:each_indexed`, `:materialize`.

### Removed (BREAKING)
- JavaScript transpiler (legacy compiler).

### Requirements
- Ruby >= 3.1 (Was >= 3.0)

### Notes
- No expected DSL changes for typical schemas; report regressions.
