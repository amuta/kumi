## [Unreleased]
### Added
- Hash objects input declarations with `hash :field do ... end` syntax
- Complete hash object integration with arrays, nesting, and broadcasting
- Runtime performance optimizations for interpreter execution
- Input load deduplication to cache loaded input values and avoid redundant operations
- Constant folding optimization to evaluate literal expressions during compilation
- Accessor memoization with proper cache isolation per input context
- Selective cache invalidation for incremental updates

### Fixed
- Cache isolation between different input contexts preventing cross-context pollution
- Cascade mutual exclusion tests now pass correctly with proper trait evaluation
- Incremental update performance with targeted cache clearing

### Performance
- 18-22% performance improvement for wide schemas
- Maintains performance for deep schemas
- Proper cache invalidation ensures correctness during incremental updates
- All optimizations verified with comprehensive test coverage (1590 examples, 0 failures)

### Technical Details
- Enhanced ExecutionEngine with input-aware cache keys
- Improved Executable cache management with field-specific invalidation
- LowerToIR pass now includes constant folding for literal expressions
- Accessor functions are memoized per input context to prevent stale results

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