# Schema Imports Architecture & Data Flow

## High-Level Flow

```
User writes schema with imports
    ↓
Parser recognizes import statements & calls
    ↓ (Phase 1: Complete ✅)
AST with ImportDeclaration + ImportCall nodes
    ↓
DEFAULT_PASSES[0]: NameIndexer
  - Registers imports as lazy references
  - Detects duplicates
    ↓ (Phase 2: Complete ✅)
state[:imported_declarations] - lazy import metadata
state[:declarations] - local declarations only
    ↓
DEFAULT_PASSES[1]: ImportAnalysisPass
  - Loads source schema.analyzed_state
  - Extracts imported declaration AST
  - Caches input_metadata from source
    ↓ (Phase 2: Complete ✅)
state[:imported_schemas] - rich source data
    ↓
DEFAULT_PASSES[2-6]: Other passes (unchanged)
    ↓
DependencyResolver (DEFAULT_PASSES[6])
  - Traces ImportCall as dependency edge
  - Creates :import_call edge type
    ↓ (Phase 3: Pending 🚧)
state[:dependencies] - includes :import_call edges
    ↓
HIR_TO_LIR_PASSES[0-2]: Normalize, ConstantFold
    ↓
HIR_TO_LIR_PASSES[3]: NASTDimensionalAnalyzerPass ⭐ CRITICAL
  - Detects ImportCall nodes
  - Builds substitution map
  - Re-analyzes source with caller's input stamps
  - REPLACES ImportCall with substituted computation
    ↓ (Phase 4: Pending 🚧)
NAST with NO ImportCall nodes (fully substituted)
    ↓
HIR_TO_LIR_PASSES[4]: SNASTPass
  - Sees only normal expressions (no imports)
  - Generates semantic stamps
    ↓
[Rest of pipeline unchanged]
    ↓
LIR (fully expanded, inlined)
    ↓
Codegen (Ruby/JS with inlined computations)
```

## Data Structures

### Phase 1: Parser Output

```ruby
# Root.imports array
[
  ImportDeclaration(
    names: [:tax, :shipping],
    module_ref: Schemas::Costs,
    loc: Location(...)
  )
]

# Declaration expression
ImportCall(
  fn_name: :tax,
  input_mapping: {
    amount: InputReference(:price),
    category: InputElementReference([:items, :item, :category])
  },
  loc: Location(...)
)
```

### Phase 2: After NameIndexer + ImportAnalysisPass

```ruby
state[:imported_declarations]
# Hash of lazy import metadata
{
  tax: {
    type: :import,
    from_module: Schemas::Tax,
    loc: Location(...)
  },
  shipping: {
    type: :import,
    from_module: Schemas::Costs,
    loc: Location(...)
  }
}

state[:imported_schemas]
# Hash of fully analyzed source data
{
  tax: {
    decl: ValueDeclaration(name: :tax, expression: ...),
    source_module: Schemas::Tax,
    source_root: Root(...),
    analyzed_state: AnalysisState({...all analysis data...}),
    input_metadata: {amount: {type: :decimal}}
  },
  shipping: {...}
}
```

### Phase 3: After DependencyResolver

```ruby
state[:dependencies]
# Now includes :import_call edges alongside :ref and :key
{
  order_total: [
    DependencyEdge(to: :tax, type: :import_call, via: ..., ...),
    DependencyEdge(to: :adjusted_price, type: :ref, via: ..., ...)
  ]
}
```

### Phase 4: After NASTDimensionalAnalyzerPass

```ruby
# Before this phase:
value :result, fn(:tax, amount: input.price)  # ImportCall in AST

# After this phase (in NAST):
value :result, (input.price * 0.15)  # ImportCall GONE, substituted

# Stamp is computed from substituted inputs:
# input.price has stamp: [] -> decimal
# So result has stamp: [] -> decimal
```

## Key State Keys

| Key | Phase | Provider | Contents |
|-----|-------|----------|----------|
| `:imported_declarations` | 2 | NameIndexer | Lazy import references |
| `:imported_schemas` | 2 | ImportAnalysisPass | Full source schema data |
| `:dependencies` | 3 | DependencyResolver | Includes `:import_call` edges |
| `:nast` | 4 | NASTDimensionalAnalyzerPass | No ImportCall nodes |
| `:snast` | 4 | SNASTPass | With dimensional stamps |

## Critical Files by Phase

### Phase 1: Parser
```
lib/kumi/syntax/import_declaration.rb     (new)
lib/kumi/syntax/import_call.rb            (new)
lib/kumi/syntax/root.rb                   (modified)
lib/kumi/core/ruby_parser/build_context.rb      (modified)
lib/kumi/core/ruby_parser/schema_builder.rb     (modified)
lib/kumi/core/ruby_parser/parser.rb             (modified)
```

### Phase 2: Name Indexing
```
lib/kumi/core/analyzer/passes/name_indexer.rb           (modified)
lib/kumi/core/analyzer/passes/import_analysis_pass.rb   (new)
lib/kumi/analyzer.rb                                     (modified - DEFAULT_PASSES)
```

### Phase 3: Dependency Resolution
```
lib/kumi/core/analyzer/passes/dependency_resolver.rb    (modify process_node())
```

### Phase 4: Type Analysis ⭐
```
lib/kumi/core/analyzer/passes/nast_dimensional_analyzer_pass.rb    (add visit_import_call)
```

### Phase 5: Integration
```
golden/schema_imports_basic/schema.kumi             (new)
golden/schema_imports_broadcasting/schema.kumi      (new)
```

## The Substitution Algorithm (Phase 4)

### Input
- Source declaration AST: `value :tax, input.amount * 0.15`
- Caller's ImportCall: `fn(:tax, amount: input.price)`
- Caller's input stamp for `input.price`: `[] -> decimal`

### Process

```
1. Create substitution map:
   {amount: {expr: InputRef(:price), stamp: [[] -> decimal]}}

2. Walk source expression with substitution:
   - See InputRef(:amount) → Replace with stamp of InputRef(:price)
   - See CallExpression(:multiply) → Recursively substitute args
   - Result: [[] -> decimal] (result of amount * 0.15)

3. Build new AST with substituted inputs:
   Becomes: (input.price * 0.15) with stamp [[] -> decimal]

4. Replace ImportCall node:
   OLD: fn(:tax, amount: input.price)  # ImportCall
   NEW: (input.price * 0.15)           # BinaryOp with stamp
```

### Broadcasting Example

If caller passes array:
```
Source: value :tax, input.amount * 0.15
Caller: fn(:tax, amount: input.items.item.price)

input.items.item.price stamp: [items] -> decimal

After substitution:
Stamp of (input.items.item.price * 0.15): [items] -> decimal

Result broadcasts automatically! ✅
```

## Error Handling

### Phase 2: Import Resolution Errors
```
- Imported name not found in source module
- Source module not a valid Kumi schema
- Failure to load source schema
```

### Phase 3: Dependency Errors
```
- Undefined import reference in ImportCall
```

### Phase 4: Type Analysis Errors
```
- Missing input field mapping (caller didn't provide all fields)
- Type mismatch (mapped expression type ≠ expected input type)
- Circular imports (schema A imports from B which imports from A)
```

## Testing Strategy

### Unit Tests (by phase)
- Phase 1: Parser tests (spec/kumi/parser_imports_spec.rb)
- Phase 2: Name indexing tests (spec/kumi/analyzer_imports_phase1_spec.rb)
- Phase 3: Dependency tests (spec/kumi/analyzer_imports_phase2_spec.rb)
- Phase 4: Type analysis tests (spec/kumi/analyzer_imports_phase3_spec.rb)

### Integration Tests
- Golden tests for end-to-end validation
- Regression tests for existing functionality

## Known Limitations & Future Work

1. **No circular import detection** - Currently not checked
2. **No lazy compilation** - Imported schemas analyzed eagerly
3. **No cross-module type checking** - Type errors only during substitution
4. **Single-level imports only** - No dynamic import graphs

These can be addressed in future phases.

## Performance Implications

### Current
- One-time cost: Analyze each imported schema once (Phase 2)
- Per-use cost: Substitute and re-analyze for each ImportCall (Phase 4)
- Memory: Cached analyzed states for all imported schemas

### Optimization opportunities
- Memoize substitution results
- Generate specialized LIR for each import call combination
- Lazy import loading

## Debugging Tips

### See imported data
```ruby
state = Kumi::Core::Analyzer::AnalysisState.new
# Run analysis up to Phase 2
puts "Imported schemas: #{state[:imported_schemas].keys}"
puts "Declarations: #{state[:declarations].keys}"
```

### Trace substitution (Phase 4)
```ruby
# Set DEBUG env var
DEBUG_NAST_DIMENSIONAL_ANALYZER=1 bin/kumi pp irv2 schema.kumi
```

### View golden test differences
```ruby
bin/kumi golden diff schema_imports_basic
```
