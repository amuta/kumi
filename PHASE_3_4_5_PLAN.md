# Schema Imports: Phases 3, 4, 5 - Detailed Implementation Plan

## Completed ✅

### Phase 1: AST & Parser
- ImportDeclaration node created
- ImportCall node created
- Root updated with imports field
- BuildContext tracks imports and imported_names
- SchemaBuilder.import() method added
- SchemaBuilder.fn() updated to recognize ImportCall
- Parser passes imports to Root
- **Status:** 18/18 tests passing ✅

### Phase 2: Name Indexing & Import Analysis
- NameIndexer registers imports as lazy references
- ImportAnalysisPass loads source schemas and caches analyzed state
- ImportAnalysisPass added to DEFAULT_PASSES (position 2)
- Duplicate detection across imports and local declarations
- **Status:** 9/9 tests passing ✅
- **Rich Data Available:**
  - `state[:imported_declarations]` - Lazy import references
  - `state[:imported_schemas]` - Full source schema info with analyzed_state

---

## Phase 3: Dependency Resolution

### Responsibility
Handle ImportCall nodes in DependencyResolver to build correct dependency edges.

### Current State
- DependencyResolver traces all declaration references
- Builds dependency graph with edge types: `:ref`, `:key`
- Needs new edge type: `:import_call` for imported function invocations

### What to Implement

#### 1. Update DependencyResolver to Handle ImportCall

**File:** `lib/kumi/core/analyzer/passes/dependency_resolver.rb`

In `process_node()`, add case for ImportCall:

```ruby
when ImportCall
  # Validate imported function exists
  unless definitions.key?(node.fn_name)
    report_error(errors,
      "undefined import reference `#{node.fn_name}`", location: node.loc)
  end

  # Add dependency edge to the imported declaration
  add_dependency_edge(graph, reverse_deps, decl.name, node.fn_name, :import_call, context[:via])

  # Trace dependencies through input mapping expressions
  # These expressions reference inputs/declarations from the CALLER schema
  node.input_mapping.each_value do |expr|
    visit_with_context(expr, context) do |n, ctx|
      process_node(n, decl, graph, reverse_deps, leaves, definitions, input_meta, errors, ctx)
    end
  end
```

**Key Points:**
- ImportCall creates dependency edge to imported declaration with type `:import_call`
- Input mapping expressions are visited/traced like normal (they reference caller's declarations/inputs)
- The imported declaration is a dependency, but its internals are resolved during Phase 4

#### 2. Edge Type Semantics

```ruby
# Existing edge types:
:ref    -> Local declaration reference (to another value/trait)
:key    -> Input field reference (to input)

# New edge type:
:import_call -> Call to imported declaration (cross-schema dependency)
```

### Tests to Write

**File:** `spec/kumi/analyzer_imports_phase2_spec.rb`

```ruby
describe "DependencyResolver with imports" do
  it "creates import_call dependency edge" do
    state = analyze_with_passes([...passes through DependencyResolver...]) do
      import :tax, from: MockSchemas::Tax
      input { decimal :price }
      value :result, fn(:tax, amount: input.price)
    end

    deps = state[:dependencies][:result]
    expect(deps.map(&:to)).to include(:tax)
    expect(deps.find { |e| e.to == :tax }.type).to eq(:import_call)
  end

  it "traces dependencies through import call input mapping" do
    state = analyze_with_passes([...]) do
      import :tax, from: MockSchemas::Tax
      input { decimal :price }
      let :adjusted_price, input.price * 1.1
      value :result, fn(:tax, amount: adjusted_price)
    end

    # result depends on both :tax (import) and :adjusted_price
    deps = state[:dependencies][:result]
    dep_names = deps.map(&:to)
    expect(dep_names).to include(:tax)
    expect(dep_names).to include(:adjusted_price)
  end

  it "handles multiple import calls in cascades" do
    state = analyze_with_passes([...]) do
      import :tax, :shipping, from: MockSchemas::Costs
      input { decimal :price }
      value :total do
        on input.price > 100, fn(:shipping, weight: 2.0)
        base fn(:tax, amount: input.price)
      end
    end

    deps = state[:dependencies][:total]
    expect(deps.map(&:to)).to include(:tax, :shipping)
  end

  it "reports error on undefined import reference" do
    expect do
      analyze_with_passes([...]) do
        input { decimal :price }
        value :result, fn(:undefined_import, amount: input.price)
      end
    end.to raise_error(Kumi::Errors::AnalysisError, /undefined import/)
  end
end
```

### Integration Points
- Already integrated in DEFAULT_PASSES after InputAccessPlannerPass
- No changes needed to Toposorter (works with any edge type)
- DependencyResolver needs only the ImportCall handling code

---

## Phase 4: Type Analysis & Substitution ⭐ CRITICAL

### Responsibility
**Transform ImportCall nodes into substituted computations with correct type stamps.**

This is where imports truly work - we inline the imported computation with caller's input mappings and get type information.

### Current State
- NASTDimensionalAnalyzerPass handles all AST nodes for type inference
- Generates NAST with dimensional stamps (` :: [dims] -> type`)
- ImportCall nodes currently unhandled

### What to Implement

#### 1. Add ImportCall Visitor to NASTDimensionalAnalyzerPass

**File:** `lib/kumi/core/analyzer/passes/nast_dimensional_analyzer_pass.rb`

```ruby
def visit(node, context)
  case node
  # ... existing cases ...

  when ImportCall
    visit_import_call(node, context)

  # ... rest of cases ...
  end
end
```

#### 2. Implement ImportCall Visitor

```ruby
def visit_import_call(node, context)
  imported_schemas = get_state(:imported_schemas)

  import_meta = imported_schemas[node.fn_name]
  unless import_meta
    raise "ImportCall for `#{node.fn_name}` not found in imported_schemas"
  end

  # Step 1: Analyze input mapping expressions in CALLER context
  # These expressions are from the calling schema, so they should use caller's input/declaration stamps
  caller_input_stamps = {}
  node.input_mapping.each do |param_name, expr|
    caller_input_stamps[param_name] = visit(expr, context)
  end

  # Step 2: Build substitution map
  # Maps source input field names to (caller expression, its stamp)
  substitution_map = build_substitution_map(
    import_meta[:input_metadata],
    node.input_mapping,
    caller_input_stamps
  )

  # Step 3: Get source declaration AST
  source_decl = import_meta[:decl]

  # Step 4: Re-analyze source declaration with substitution
  # Key: When we visit InputRef nodes in the source, we replace them with caller's expressions
  result_stamp = visit_with_substitution(
    source_decl.expression,
    substitution_map,
    context
  )

  # Step 5: Cache the substitution result for later LIR generation
  @import_call_substitutions[node] = {
    substituted_ast: source_decl.expression,  # We'll need to build the actual substituted AST
    result_stamp: result_stamp
  }

  result_stamp
end
```

#### 3. Substitution Logic

The core of Phase 4 is correct substitution:

```ruby
def visit_with_substitution(node, substitution_map, context)
  case node
  when InputReference
    # Replace with caller's expression stamp
    substitute_input_ref(node, substitution_map)

  when InputElementReference
    # Handle array element references
    substitute_input_element_ref(node, substitution_map)

  when DeclarationReference
    # Local references within source schema
    # These should be analyzed using source's declarations, not caller's
    visit(node, context)

  when CallExpression
    # Recursively analyze arguments with substitution
    args_stamps = node.args.map { |arg| visit_with_substitution(arg, substitution_map, context) }
    # Infer call type using replaced argument stamps
    infer_call_type(node.fn_name, args_stamps, context)

  when CascadeExpression
    # Visit cascade cases with substitution
    # Each case has conditions and expression
    node.cases.each do |case_node|
      visit_with_substitution(case_node.condition, substitution_map, context) if case_node.condition
    end
    # Result stamp depends on all case possibilities
    visit_with_substitution(node.cases.last.expression, substitution_map, context)

  else
    # Leaf nodes, literals, etc. - no substitution needed
    visit(node, context)
  end
end

def substitute_input_ref(node, substitution_map)
  # node.name is the field name in source schema (e.g., :amount)
  sub = substitution_map[node.name]

  unless sub
    raise "Input field `#{node.name}` not mapped in ImportCall"
  end

  # Return the stamp from caller's expression
  # (The expression was already analyzed in caller's context)
  sub[:stamp]
end

def substitute_input_element_ref(node, substitution_map)
  # node.path = [:field1, :field2, :value]
  root_field = node.path.first

  sub = substitution_map[root_field]
  unless sub
    raise "Root input field `#{root_field}` not mapped in ImportCall"
  end

  # If caller passed an array, element access continues to work
  # Stamp already includes the array dimensions
  sub[:stamp]
end

def build_substitution_map(source_input_schema, input_mapping, caller_input_stamps)
  # source_input_schema is a hash: {field_name: metadata}
  # input_mapping is: {param_name: caller_expr}
  # caller_input_stamps is: {param_name: stamp}

  map = {}
  input_mapping.each do |param_name, caller_expr|
    source_field = source_input_schema.find { |f| f.name == param_name }

    unless source_field
      raise "Source input field `#{param_name}` not found in #{source_module}"
    end

    map[param_name] = {
      expr: caller_expr,
      stamp: caller_input_stamps[param_name]
    }
  end
  map
end
```

#### 4. Key Insight: Automatic Broadcasting

When caller passes array to source expecting scalar:
```
Source: value :tax, input.amount * 0.15
Caller: tax(amount: input.items.item.price)

input.items.item.price stamp: [items] -> decimal

After substitution:
stamp of result: [items] -> decimal (because the substituted param has that shape)
```

The **result automatically broadcasts** because the substituted input has dimensions!

### Tests to Write

**File:** `spec/kumi/analyzer_imports_phase3_spec.rb`

```ruby
describe "NASTDimensionalAnalyzerPass with imports" do
  include AnalyzerStateHelper

  it "substitutes input references and derives correct stamp" do
    # Source: value :tax, input.amount * 0.15
    # Caller: value :result, tax(amount: input.price)
    # Expected: result stamp = [] -> decimal

    state = analyze_up_to(:nast_dimensional) do
      import :tax, from: MockSchemas::Tax
      input { decimal :price }
      value :result, fn(:tax, amount: input.price)
    end

    result_stamp = state[:nast][:result].stamp  # Assuming NAST available
    expect(result_stamp.dimensions).to be_empty
    expect(result_stamp.type).to eq(:decimal)
  end

  it "broadcasts with array arguments" do
    # Source: value :discount, price * 0.8
    # Caller: value :items_discounted, discount(price: input.items.item.price)
    # Expected: result stamp = [items] -> decimal

    state = analyze_up_to(:nast_dimensional) do
      import :discount, from: MockSchemas::Discount
      input do
        array :items do
          hash :item do
            decimal :price
          end
        end
      end
      value :items_discounted, fn(:discount, price: input.items.item.price)
    end

    result_stamp = state[:nast][:items_discounted].stamp
    expect(result_stamp.dimensions).to eq([:items])
    expect(result_stamp.type).to eq(:decimal)
  end

  it "traces nested import calls" do
    # TaxRate schema: value :total, input.amount + tax
    # Shipping schema: imports TaxRate.total
    # Caller: imports Shipping.with_tax

    state = analyze_up_to(:nast_dimensional) do
      import :with_tax, from: MockSchemas::Shipping
      input { decimal :weight }
      value :final, fn(:with_tax, weight: input.weight)
    end

    # Should correctly resolve nested imports
    expect(state[:nast][:final]).to be_truthy
  end

  it "handles complex expressions in mapping" do
    state = analyze_up_to(:nast_dimensional) do
      import :tax, from: MockSchemas::Tax
      input do
        decimal :base_price
        decimal :markup
      end
      value :result, fn(:tax, amount: input.base_price * input.markup)
    end

    result_stamp = state[:nast][:result].stamp
    expect(result_stamp.type).to eq(:decimal)
  end

  it "errors on type mismatch" do
    # Source expects decimal, caller provides integer
    expect do
      analyze_up_to(:nast_dimensional) do
        import :tax, from: MockSchemas::Tax
        input { integer :price }
        value :result, fn(:tax, amount: input.price)
      end
    end.to raise_error  # Type mismatch (if strict typing is enforced)
  end

  it "replaces ImportCall with substituted computation in NAST" do
    # After phase 4, ImportCall should be gone, replaced with inlined computation
    state = analyze_up_to(:snast)  # SNASTPass runs after NASTDimensionalAnalyzer

    # SNAST should have NO ImportCall nodes
    result_decl = state[:snast][:result]
    expect(result_decl.expression).not_to be_a(Kumi::Syntax::ImportCall)
    # Should be the inlined computation
    expect(result_decl.expression).to be_a(Kumi::Syntax::CallExpression)  # * and +
  end
end
```

### Integration Points
- Runs in HIR_TO_LIR_PASSES (position 3: after NormalizeToNASTPass, ConstantFoldingPass)
- **Before SNASTPass** (position 4) - SNASTPass should not see any ImportCall nodes
- After this phase, ImportCalls are completely resolved to inlined computations

### Critical Detail: AST Mutation

The substituted computation needs to become part of the declaration AST. After Phase 4:

```
Original ImportCall node:
value :result, fn(:tax, amount: input.price)

After NASTDimensionalAnalyzerPass:
value :result, (input.price * 0.15)   # Fully inlined, no ImportCall
```

This requires either:
1. Building a new substituted AST tree, OR
2. Storing the substitution in a cache and using it in later passes

### Implementation Strategy for Phase 4

1. **Create substitution visitor** that walks source AST and replaces InputRef nodes
2. **Cache substitution results** in analyzer state
3. **Build substituted AST** from the cache
4. **Replace ImportCall node** in the caller's declaration expression
5. **Analyze the new substituted AST** for type stamps
6. **Store result stamp** in output NAST

---

## Phase 5: Integration & End-to-End

### Responsibility
Wire everything together and test full pipeline.

### What to Implement

#### 1. LIR Generation
No special handling needed - ImportCalls are gone by this phase.
LIR sees only normal CallExpressions (the inlined computations).

#### 2. Codegen
No special handling needed - just generates code for inlined computations.

### Golden Test

**File:** `golden/schema_imports_basic/schema.kumi`

```kumi
schema do
  import :tax, from: Schemas::Tax

  input do
    decimal :price
  end

  value :total, price + tax(amount: price)
end
```

**Expected output for input {price: 100}:**
```
{
  total: 115.0  # 100 + (100 * 0.15)
}
```

**File:** `golden/schema_imports_broadcasting/schema.kumi`

```kumi
schema do
  import :discounted, from: Schemas::Discount

  input do
    array :items do
      hash :item do
        decimal :price
      end
    end
    decimal :discount_rate
  end

  value :results, discounted(price: input.items.item.price, rate: input.discount_rate)
end
```

**Expected:** Array of discounted prices (broadcasting to [items] dimension)

#### 3. Run Existing Tests
Ensure no regression in existing tests.

#### 4. Clean Up
- Remove temporary debug code
- Verify error messages are clear
- Document any gotchas

---

## Summary of All Phases

| Phase | Task | Files | Tests | Status |
|-------|------|-------|-------|--------|
| 1 | AST & Parser | import_declaration.rb, import_call.rb, root.rb, build_context.rb, schema_builder.rb, parser.rb | parser_imports_spec.rb | ✅ 18/18 |
| 2 | Name Indexing & Analysis | name_indexer.rb (modified), import_analysis_pass.rb, analyzer.rb (modified) | analyzer_imports_phase1_spec.rb | ✅ 9/9 |
| 3 | Dependency Resolution | dependency_resolver.rb (modified) | analyzer_imports_phase2_spec.rb | 🚧 Pending |
| 4 | Type Analysis & Substitution | nast_dimensional_analyzer_pass.rb (modified) | analyzer_imports_phase3_spec.rb | 🚧 Pending |
| 5 | Integration & Golden Tests | (no new files) | golden tests | 🚧 Pending |

---

## Implementation Checklist

### Phase 3: Dependency Resolution
- [ ] Add ImportCall case to process_node in DependencyResolver
- [ ] Create `:import_call` edge type
- [ ] Write tests (10-15 tests expected)
- [ ] Verify Toposorter still works with import edges
- [ ] Commit with message: "feat: Add ImportCall dependency resolution"

### Phase 4: Type Analysis & Substitution ⭐
- [ ] Add ImportCall visitor to NASTDimensionalAnalyzerPass
- [ ] Implement substitution logic for InputRef and InputElementReference
- [ ] Implement substitution logic for CallExpression (recursive)
- [ ] Implement substitution logic for CascadeExpression
- [ ] Build substituted AST and replace ImportCall node
- [ ] Handle type inference for substituted computation
- [ ] Cache substitution results in analyzer state
- [ ] Write comprehensive tests (15-20 tests expected)
- [ ] Test broadcasting with array arguments
- [ ] Test nested import calls
- [ ] Test complex expressions in mapping
- [ ] Verify no ImportCall nodes remain after SNASTPass
- [ ] Commit with message: "feat: Add type analysis and substitution for imports"

### Phase 5: Integration & End-to-End
- [ ] Create golden test: schema_imports_basic
- [ ] Create golden test: schema_imports_broadcasting
- [ ] Run: `bin/kumi golden verify schema_imports_*`
- [ ] Run full test suite to check for regressions
- [ ] Update PLAN.md with completion notes
- [ ] Commit with message: "feat: Complete schema imports implementation with golden tests"

---

## Key Insights from Phases 1-2

1. **ImportCall nodes bridge schemas** - They're recognized during parsing and carried through analysis
2. **Analyzed state is rich** - Source schemas provide full analysis data (types, dependencies)
3. **Lazy resolution** - Imports are registered early but fully resolved in Phase 4
4. **No special IR needed** - After substitution, everything looks like normal inline code

## Next Steps

1. Implement Phase 3 (Dependency Resolution) - relatively straightforward
2. Implement Phase 4 (Substitution) - the heart of the feature, most complex
3. Implement Phase 5 (Golden tests) - validates everything works end-to-end
