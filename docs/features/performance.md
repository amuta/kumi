# Performance

Analysis, compilation, and execution performance for large schemas.

## Execution Model

**Compilation:**
- Each expression compiled to executable lambda
- Direct function calls for operations

**Runtime:**
- Result caching to avoid recomputation
- Selective evaluation: only requested keys computed
- Direct lambda invocation