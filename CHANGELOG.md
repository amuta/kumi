## [Unreleased]
### Added
- Documentation for `element :any` syntax as alternative to hash objects for dynamic data
- Comprehensive spec coverage for `element :any` hash access patterns
- Working examples in SYNTAX.md, hierarchical-broadcasting.md, and input-declaration-system.md

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