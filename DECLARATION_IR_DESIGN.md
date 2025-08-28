# Declaration-Based IR Design

## Current Problem
The IRV2 pass creates a flat list of operations where references are inlined, losing structural boundaries.

## Better Approach: Declaration IR

### Structure
```
Module {
  declarations: Map<Name, Declaration>
  evaluation_order: [Name]
}

Declaration {
  name: Symbol
  inputs: [InputRef]  // What external inputs this needs
  dependencies: [Name]  // What other declarations this references  
  operations: [Operation]  // Local operations
  result: OperationId  // Which operation produces the result
}
```

### Example Output
```
; — Module: hierarchical_complex

Declaration high_performer {
  inputs: [[:regions, :offices, :teams, :employees, :rating]]
  dependencies: []
  operations: [
    %0 = LoadInput [:regions, :offices, :teams, :employees, :rating]
    %1 = Const(4.5)
    %2 = AlignTo(%1, [:regions,:offices,:teams,:employees])
    %3 = Map(core.gte, %0, %2)
  ]
  result: %3
}

Declaration employee_bonus {
  inputs: [[:regions, :offices, :teams, :employees, :salary]]
  dependencies: [high_performer, senior_level, top_team]
  operations: [
    %0 = LoadInput [:regions, :offices, :teams, :employees, :salary]
    %1 = LoadDecl high_performer
    %2 = LoadDecl senior_level  
    %3 = LoadDecl top_team
    %4 = AlignTo(%3, [:regions,:offices,:teams,:employees])
    %5 = Map(core.and, %2, %4)
    %6 = Map(core.and, %1, %5)
    ...
  ]
  result: %15
}
```

### Backend Benefits
1. **Separate compilation** - each declaration is self-contained
2. **Dependency analysis** - explicit dependency graph
3. **Parallel compilation** - independent declarations can compile in parallel
4. **Optimization boundaries** - clear scopes for optimization
5. **Code reuse** - declarations can be cached/memoized
6. **Incremental compilation** - only recompile changed declarations

### Implementation Notes
- `LoadDecl` operations represent references to other declarations
- Each declaration has its own operation ID space (can start from %0)
- Dependencies must be topologically sorted in evaluation_order
- Input deduplication happens at module level, not within declarations