# Features

## Core Features

### [Unsatisfiability Detection](analysis-unsat-detection.md)
Analyzes rule combinations to detect logical impossibilities across dependency chains.

- Detects impossible combinations at compile-time
- Validates domain constraints
- Reports multiple errors

### [Cascade Mutual Exclusion](analysis-cascade-mutual-exclusion.md)
Enables safe mutual recursion when cascade conditions are mutually exclusive.

- Allows mathematically sound recursive patterns
- Detects mutually exclusive conditions
- Prevents unsafe cycles while enabling safe ones

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

### [Hierarchical Broadcasting](hierarchical-broadcasting.md)
Automatic vectorization over hierarchical data structures with dual access modes.

- Object access for structured business data
- Element access for multi-dimensional arrays
- Mixed access modes in same schema

### [Performance](performance.md)
Processes large schemas.

- Result caching
- Selective evaluation

### [S-Expression Printer](s-expression-printer.md)
Debug and inspect AST structures with readable S-expression notation output.

- Visitor pattern implementation for all node types
- Proper indentation and hierarchical structure
- Useful for debugging schema parsing and AST analysis

### [JavaScript Transpiler](javascript-transpiler.md)
Transpiles compiled schemas to standalone JavaScript code.

- Generates bundles with only required functions
- Supports CommonJS and browser environments
- Maintains identical behavior across platforms

## Integration

- Type inference uses input declarations
- Unsatisfiability detection uses type information for validation
- Cascade mutual exclusion integrates with dependency analysis and cycle detection
- Performance optimizations apply to all analysis passes