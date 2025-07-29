# Features

## Core Features

### [Unsatisfiability Detection](analysis-unsat-detection.md)
Analyzes rule combinations to detect logical impossibilities across dependency chains.

- Detects impossible combinations at compile-time
- Validates domain constraints
- Reports multiple errors

### [Type Inference](analysis-type-inference.md)  
Determines types from expressions and propagates them through dependencies.

- Infers types from literals and function calls
- Propagates types through dependency graph
- Validates function arguments

### [Input Declarations](input-declaration-system.md)
Defines expected inputs with types and constraints.

- Type-specific declaration methods
- Domain validation at runtime
- Separates input metadata from business logic

### [Performance](performance.md)
TODO: Add benchmark data
Processes large schemas with optimized algorithms.

- Result caching
- Selective evaluation

## Integration

- Type inference uses input declarations
- Mathematical reasoning uses type information for validation
- Performance optimizations apply to all analysis passes