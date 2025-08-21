## [Unreleased]

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