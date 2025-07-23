## [Unreleased]

### Changed
- **BREAKING**: Replaced `StrictCycleChecker` with `AtomUnsatSolver` for stack-safe UNSAT detection
- Refactored cycle detection to use iterative Kahn's topological sort algorithm instead of recursive DFS
- Added support for always-false comparison detection (e.g., `100 < 100`)

### Added  
- Depth-safe UNSAT detection handles 30k+ node graphs without stack overflow
- Comprehensive test suite for large graph scenarios (acyclic ladders, cycles, mixed constraints)
- Enhanced documentation with YARD comments for `AtomUnsatSolver` module
- Extracted `StrictInequalitySolver` module for clear separation of cycle detection logic

### Performance
- **Stack-safe UNSAT detection**: Eliminates `SystemStackError` in constraint analysis for 30k+ node graphs
- **Fixed gather_atoms recursion**: Made AST traversal iterative to handle deep dependency chains
- Sub-millisecond performance on 10k-20k node constraint graphs with cycle detection
- Maintained identical UNSAT detection correctness for all existing scenarios
- **Note**: Deep schemas (2500+ dependencies) may still hit Ruby stack limits in compilation/evaluation phases

## [0.1.0] - 2025-07-01

- Initial release
