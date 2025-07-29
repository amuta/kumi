# Performance

TODO: Add benchmark data

Processes large schemas with optimized algorithms for analysis, compilation, and execution.

## Execution Model

**Compilation:**
- Each expression compiled to executable lambda
- Direct function calls for operations

**Runtime:**
- Result caching to avoid recomputation
- Selective evaluation: only requested keys computed
- Direct lambda invocation