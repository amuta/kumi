# Schema Imports Feature - Current Status

## ✅ Completed: Phases 1 & 2

### Phase 1: AST & Parser (100% Complete)
**Branch:** `feature/schema-imports`
**Tests:** 18/18 passing ✅

**What was implemented:**
- `ImportDeclaration` AST node - represents `import :name, from: Module`
- `ImportCall` AST node - represents `fn_name(field: expr, ...)`
- `Root` updated to include `imports` field
- `BuildContext` tracks `@imports` and `@imported_names`
- `SchemaBuilder.import()` DSL method
- `SchemaBuilder.fn()` updated to recognize ImportCall vs CallExpression
- `Parser` passes imports to Root constructor

**Recognition Logic:**
- ImportCall created only if: fn_name in imported_names ✓ AND all args are kwargs ✓

**Files Created:**
- lib/kumi/syntax/import_declaration.rb
- lib/kumi/syntax/import_call.rb
- spec/kumi/parser_imports_spec.rb

**Files Modified:**
- lib/kumi/syntax/root.rb
- lib/kumi/core/ruby_parser/build_context.rb
- lib/kumi/core/ruby_parser/schema_builder.rb
- lib/kumi/core/ruby_parser/parser.rb

---

### Phase 2: Name Indexing & Import Analysis (100% Complete)
**Tests:** 9/9 passing ✅

**What was implemented:**
- `NameIndexer` registers imports as lazy references in `state[:imported_declarations]`
- `ImportAnalysisPass` loads source schemas and caches analyzed state
- `ImportAnalysisPass` added to DEFAULT_PASSES (position 2, after NameIndexer)
- Duplicate detection across imports and local declarations
- Mock schema support with `kumi_schema_instance`, `analyzed_state`, `input_metadata`

**Rich Data Available After Phase 2:**
```ruby
state[:imported_declarations]
# {tax: {type: :import, from_module: Schemas::Tax, loc: ...}, ...}

state[:imported_schemas]
# {tax: {decl: ..., source_module: ..., analyzed_state: {...}, input_metadata: {...}}, ...}
```

**Files Created:**
- lib/kumi/core/analyzer/passes/import_analysis_pass.rb
- spec/kumi/analyzer_imports_phase1_spec.rb

**Files Modified:**
- lib/kumi/core/analyzer/passes/name_indexer.rb
- lib/kumi/analyzer.rb

---

## 🚧 Pending: Phases 3, 4, 5

### Phase 3: Dependency Resolution (Ready to Start 🚧)
**Documentation:** PHASE_3_4_5_PLAN.md (section "Phase 3: Dependency Resolution")

**Estimated Scope:**
- Update DependencyResolver to handle ImportCall nodes
- Create `:import_call` dependency edge type
- 10-15 test cases
- ~50-100 lines of code

**Key Changes:**
- lib/kumi/core/analyzer/passes/dependency_resolver.rb (process_node() method)
- spec/kumi/analyzer_imports_phase2_spec.rb (new)

**What it does:**
- Traces ImportCall nodes as dependency edges
- Validates imported function exists
- Traces input mapping expressions as dependencies

---

### Phase 4: Type Analysis & Substitution ⭐ CRITICAL (Ready to Start 🚧)
**Documentation:** PHASE_3_4_5_PLAN.md (section "Phase 4: Type Analysis & Substitution")

**Estimated Scope:**
- Add ImportCall visitor to NASTDimensionalAnalyzerPass
- Implement substitution logic for all node types
- 15-20 test cases
- ~200-300 lines of code (most complex phase)

**Key Insight:** This is where imports truly work!

**What it does:**
1. Detects ImportCall nodes during type analysis
2. Analyzes input mapping expressions in caller's context
3. Builds substitution map: source input fields → caller expressions
4. Re-analyzes source declaration with substituted inputs
5. Replaces ImportCall with inlined computation
6. Returns correct type stamp (with automatic broadcasting!)

**Example:**
```
Source: value :tax, input.amount * 0.15
Caller: value :result, fn(:tax, amount: input.price)

After Phase 4:
value :result, (input.price * 0.15)  # Inlined, ImportCall gone

Stamp of result: [] -> decimal (from input.price)
```

**Broadcast Example:**
```
Caller: value :items_tax, fn(:tax, amount: input.items.item.price)
input.items.item.price stamp: [items] -> decimal

After Phase 4:
Stamp of items_tax: [items] -> decimal  # Broadcasts automatically!
```

**Files to Modify:**
- lib/kumi/core/analyzer/passes/nast_dimensional_analyzer_pass.rb

**New Files:**
- spec/kumi/analyzer_imports_phase3_spec.rb

---

### Phase 5: Integration & End-to-End (Ready to Start 🚧)
**Documentation:** PHASE_3_4_5_PLAN.md (section "Phase 5: Integration & End-to-End")

**Estimated Scope:**
- Create 2-3 golden tests
- 5-10 test cases
- No new code (just integration)

**What it does:**
1. Creates golden test schemas with imports
2. Verifies end-to-end compilation and execution
3. Tests broadcasting with array arguments
4. Checks for regressions in existing tests

**Golden Tests:**
- golden/schema_imports_basic/schema.kumi - Simple scalar import
- golden/schema_imports_broadcasting/schema.kumi - Array broadcasting

---

## Development Checklist

### Phase 3 Implementation Checklist
- [ ] Read PHASE_3_4_5_PLAN.md "Phase 3" section
- [ ] Read IMPORTS_ARCHITECTURE.md for context
- [ ] Add ImportCall case to DependencyResolver.process_node()
- [ ] Write 10-15 tests in analyzer_imports_phase2_spec.rb
- [ ] Run tests: bundle exec rspec spec/kumi/analyzer_imports_phase2_spec.rb
- [ ] Verify existing tests still pass
- [ ] Commit: "feat: Add ImportCall dependency resolution"

### Phase 4 Implementation Checklist ⭐
- [ ] Read PHASE_3_4_5_PLAN.md "Phase 4" section carefully
- [ ] Read IMPORTS_ARCHITECTURE.md "Substitution Algorithm" section
- [ ] Add visit_import_call() to NASTDimensionalAnalyzerPass
- [ ] Implement build_substitution_map()
- [ ] Implement visit_with_substitution() for all node types
- [ ] Implement substitute_input_ref() and substitute_input_element_ref()
- [ ] Write 15-20 tests in analyzer_imports_phase3_spec.rb
- [ ] Test scalar substitution
- [ ] Test array broadcasting
- [ ] Test complex expressions
- [ ] Test nested import calls
- [ ] Run tests: bundle exec rspec spec/kumi/analyzer_imports_phase3_spec.rb
- [ ] Verify no ImportCall nodes remain after SNASTPass
- [ ] Verify existing tests still pass
- [ ] Commit: "feat: Add type analysis and substitution for imports"

### Phase 5 Implementation Checklist
- [ ] Create golden/schema_imports_basic/schema.kumi
- [ ] Create golden/schema_imports_broadcasting/schema.kumi
- [ ] Run: bin/kumi golden update schema_imports_*
- [ ] Run: bin/kumi golden verify schema_imports_*
- [ ] Run full test suite: bundle exec rspec
- [ ] Check for regressions
- [ ] Update PLAN.md with completion notes
- [ ] Commit: "feat: Complete schema imports with golden tests"

---

## How to Get Started

### For Phase 3
```bash
# 1. Read the plan
cat PHASE_3_4_5_PLAN.md | grep -A 100 "Phase 3:"

# 2. Read the architecture
cat IMPORTS_ARCHITECTURE.md

# 3. Look at existing DependencyResolver
vim lib/kumi/core/analyzer/passes/dependency_resolver.rb

# 4. Start writing tests
vim spec/kumi/analyzer_imports_phase2_spec.rb

# 5. Run tests to see what fails
bundle exec rspec spec/kumi/analyzer_imports_phase2_spec.rb

# 6. Implement based on test failures
vim lib/kumi/core/analyzer/passes/dependency_resolver.rb
```

### For Phase 4
```bash
# 1. Read the plan - especially "Substitution Algorithm"
cat PHASE_3_4_5_PLAN.md | grep -A 200 "Phase 4:"

# 2. Study the examples
cat IMPORTS_ARCHITECTURE.md | grep -A 50 "Substitution Algorithm"

# 3. Look at NASTDimensionalAnalyzerPass structure
vim lib/kumi/core/analyzer/passes/nast_dimensional_analyzer_pass.rb

# 4. Write comprehensive tests first (TDD!)
vim spec/kumi/analyzer_imports_phase3_spec.rb

# 5. Implement step by step following test failures
```

### For Phase 5
```bash
# 1. Create golden test schemas
mkdir -p golden/schema_imports_basic golden/schema_imports_broadcasting

# 2. Create test files (see PHASE_3_4_5_PLAN.md for examples)
vim golden/schema_imports_basic/schema.kumi
vim golden/schema_imports_broadcasting/schema.kumi

# 3. Generate expected outputs
bin/kumi golden update schema_imports_*

# 4. Verify they work
bin/kumi golden verify schema_imports_*

# 5. Run all tests
bundle exec rspec
```

---

## Key Resources

### Documentation
- **PLAN.md** - Original global plan
- **PHASE_3_4_5_PLAN.md** - Detailed Phase 3-5 implementation guide (READ THIS!)
- **IMPORTS_ARCHITECTURE.md** - Architecture overview and data flow (READ THIS!)
- **CURRENT_STATUS.md** - This file

### Test Files by Phase
- Phase 1: spec/kumi/parser_imports_spec.rb (18/18 ✅)
- Phase 2: spec/kumi/analyzer_imports_phase1_spec.rb (9/9 ✅)
- Phase 3: spec/kumi/analyzer_imports_phase2_spec.rb (pending)
- Phase 4: spec/kumi/analyzer_imports_phase3_spec.rb (pending)
- Phase 5: golden/schema_imports_*/schema.kumi (pending)

### Implementation Files
- **Phase 1-2 Complete:**
  - lib/kumi/syntax/import_*.rb (created)
  - lib/kumi/core/ruby_parser/*.rb (modified)
  - lib/kumi/core/analyzer/passes/name_indexer.rb (modified)
  - lib/kumi/core/analyzer/passes/import_analysis_pass.rb (created)
  - lib/kumi/analyzer.rb (modified)

- **Phase 3 Todo:**
  - lib/kumi/core/analyzer/passes/dependency_resolver.rb (modify process_node)

- **Phase 4 Todo:**
  - lib/kumi/core/analyzer/passes/nast_dimensional_analyzer_pass.rb (add visitor)

- **Phase 5 Todo:**
  - golden/schema_imports_*/schema.kumi (create)

---

## Branch Info

**Current Branch:** `feature/schema-imports`

Created from: `refactor/pass-manager-and-execution-framework`

**Commits:**
1. docs: Add schema imports implementation plan
2. feat: Add AST nodes and parser support for schema imports
3. feat: Add name indexing and import analysis for schema imports
4. refactor: Fetch rich analyzed state from imported schemas
5. docs: Add comprehensive Phase 3-5 implementation guides

---

## Git Commands

```bash
# View current branch
git branch

# View commits
git log --oneline | head -20

# View changes
git diff main feature/schema-imports

# Switch to branch
git checkout feature/schema-imports

# After Phase 3 complete
git commit -m "feat: Add ImportCall dependency resolution"

# After Phase 4 complete
git commit -m "feat: Add type analysis and substitution for imports"

# After Phase 5 complete
git commit -m "feat: Complete schema imports with golden tests"

# Create PR when ready
git push origin feature/schema-imports
# Then: gh pr create --web
```

---

## Next Actions

1. **Read Documentation:**
   - PHASE_3_4_5_PLAN.md (for next phase details)
   - IMPORTS_ARCHITECTURE.md (for context)

2. **Start Phase 3:**
   - Implement ImportCall handling in DependencyResolver
   - Write tests first (TDD)
   - ~2-3 hours of work

3. **Continue to Phase 4:**
   - Most critical and complex phase
   - Implement substitution logic
   - ~4-6 hours of work

4. **Complete with Phase 5:**
   - Create golden tests
   - Verify end-to-end
   - ~1-2 hours of work

**Total Remaining Effort:** ~7-11 hours of implementation

---

## Success Criteria

Phase 3 ✅: Dependency graph correctly includes :import_call edges
Phase 4 ✅: ImportCall nodes replaced with substituted computations, types correct, broadcasting works
Phase 5 ✅: Golden tests pass, no regressions in existing tests

All 3 phases complete = Schema imports feature fully implemented! 🎉
