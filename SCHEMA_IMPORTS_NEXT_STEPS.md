# Schema Imports Feature - Next Steps & Context

## Current Status
- ✅ **Phases 1-4 Complete**: 44 unit tests passing
- ✅ **Phase 5 Partial**: Golden tests created but don't actually test imports (they're just regular schemas)
- 🚧 **TODO**: Make golden tests actually use the import feature

## The Problem with Current Golden Tests
The golden test schemas (`golden/schema_imports_basic/` and `golden/schema_imports_broadcasting/`) don't actually import anything. They're just regular `.kumi` files without any `import` statements.

**Why?** Golden test schemas are just `.kumi` files without a Ruby module context, so they can't reference other schemas as modules (e.g., `from: Schemas::Tax`).

## The Solution: Create a Test Fixture Infrastructure
The user suggested looking at how existing test fixtures work. Key findings:

1. **Existing patterns in `/home/muta/repos/kumi/spec/support/`:**
   - `analyzer_state_helper.rb` - runs analyzer passes on inline DSL blocks
   - `pass_test_helper.rb` - runs individual passes with schema blocks
   - `schema_fixture_helper.rb` - requires fixture schemas from `/spec/fixtures/schemas/`

2. **The DSL already supports imports:**
   - `SchemaBuilder` has `import(*names, from:)` method
   - Parser recognizes `import` statements and creates `ImportDeclaration` nodes
   - Just needs a way to provide module references for golden tests

## Implementation Plan

### Step 1: Create Golden Schema Modules in Test Setup
Instead of using `GoldenSchemaWrapper`, use the simpler approach that works with existing test patterns:

**Location:** `/home/muta/repos/kumi/spec/support/golden_schema_modules.rb`

Create modules for golden schemas that will be imported:
```ruby
module GoldenSchemas
  module Tax
    def self.kumi_schema_instance
      # Load and analyze golden/schema_imports_tax_base/schema.kumi
      # Return analyzed schema object
    end
  end

  module Discount
    def self.kumi_schema_instance
      # Load and analyze another golden schema
    end
  end
end
```

### Step 2: Update Golden Test Schemas to Use Imports

**File:** `golden/schema_imports_with_tax/schema.kumi`
```kumi
import :tax, from: GoldenSchemas::Tax

schema do
  input do
    decimal :price
  end

  value :total, input.price + fn(:tax, amount: input.price)
end
```

**File:** `golden/schema_imports_with_broadcasting/schema.kumi`
```kumi
import :tax, from: GoldenSchemas::Tax

schema do
  input do
    array :items do
      hash :item do
        decimal :amount
      end
    end
  end

  value :item_taxes, fn(:tax, amount: input.items.item.amount)
end
```

### Step 3: Make Golden Tests Load the Modules
Modify the golden test runner to:
1. Load `/spec/support/golden_schema_modules.rb` before running golden tests
2. Ensure `GoldenSchemas::*` modules are available to golden schemas

### Step 4: Clean Up Old Test Schemas
Remove or repurpose:
- `golden/schema_imports_basic/` - either delete or rename to a non-import test
- `golden/schema_imports_broadcasting/` - same as above

## Files to Create/Modify

### New Files
1. `/home/muta/repos/kumi/spec/support/golden_schema_modules.rb` (150-200 lines)
   - Define `GoldenSchemas::Tax`, `GoldenSchemas::Discount`, etc.
   - Load and analyze golden schemas
   - Implement `kumi_schema_instance` method for each

2. `golden/schema_imports_tax_base/schema.kumi` (already exists)
   - Base tax calculation schema to be imported

3. `golden/schema_imports_with_imports/schema.kumi` (NEW)
   - Uses `import :tax, from: GoldenSchemas::Tax`
   - Tests scalar import

4. `golden/schema_imports_broadcasting_with_imports/schema.kumi` (NEW)
   - Uses `import :tax, from: GoldenSchemas::Tax`
   - Tests broadcasting with imports

### Modified Files
1. `spec/spec_helper.rb`
   - Maybe add: `require_relative "support/golden_schema_modules"` if needed

### Delete/Archive
- `golden/schema_imports_basic/` (fake test)
- `golden/schema_imports_broadcasting/` (fake test)

## Implementation Checklist

- [ ] Create `/spec/support/golden_schema_modules.rb`
  - [ ] Load golden schemas via `Kumi::Core::RubyParser::Dsl.build_syntax_tree`
  - [ ] Analyze each schema using full DEFAULT_PASSES
  - [ ] Extract input_metadata from schema
  - [ ] Create module with `kumi_schema_instance` method
  - [ ] Define `GoldenSchemas::Tax`
  - [ ] Define `GoldenSchemas::Discount` (optional)

- [ ] Create `golden/schema_imports_with_imports/schema.kumi`
  - [ ] Import from `GoldenSchemas::Tax`
  - [ ] Test simple scalar parameter mapping
  - [ ] Include input.json and expected/ outputs

- [ ] Create `golden/schema_imports_broadcasting_with_imports/schema.kumi`
  - [ ] Import from `GoldenSchemas::Tax`
  - [ ] Test array broadcasting through import
  - [ ] Include input.json and expected/ outputs

- [ ] Run golden test generation
  ```bash
  bin/kumi golden update schema_imports_with_imports schema_imports_broadcasting_with_imports
  ```

- [ ] Verify golden tests pass
  ```bash
  bin/kumi golden verify schema_imports_with_imports schema_imports_broadcasting_with_imports
  ```

- [ ] Clean up old fake test schemas
  - [ ] Remove `golden/schema_imports_basic/`
  - [ ] Remove `golden/schema_imports_broadcasting/`

- [ ] Delete `/lib/kumi/dev/golden_schema_wrapper.rb` (not needed)

- [ ] Verify all Phase 1-4 unit tests still pass
  ```bash
  bundle exec rspec spec/kumi/parser_imports_spec.rb \
    spec/kumi/analyzer_imports_phase*.rb -v
  ```

- [ ] Commit final changes
  - Message: "feat: Create proper golden tests with actual schema imports"

## Key Code Reference

### How to Load & Analyze a Golden Schema

```ruby
# Load schema file
schema_path = File.expand_path("../golden/schema_imports_tax_base/schema.kumi", __dir__)
content = File.read(schema_path)
schema_root = Kumi::Core::RubyParser::Dsl.build_syntax_tree { instance_eval(content) }

# Analyze it
registry = Kumi::RegistryV2.load
state = Kumi::Core::Analyzer::AnalysisState.new({})
state = state.with(:registry, registry)
errors = []

Kumi::Analyzer::DEFAULT_PASSES.each do |pass_class|
  pass = pass_class.new(schema_root, state)
  state = pass.run(errors)
  raise "Analysis failed: #{errors.map(&:to_s).join(', ')}" unless errors.empty?
end

# Extract input metadata
input_metadata = {}
schema_root.inputs&.each do |input_decl|
  input_metadata[input_decl.name] = { type: input_decl.type_spec&.kind || :any }
end

# Create the module
module GoldenSchemas::Tax
  def self.kumi_schema_instance
    @instance ||= begin
      obj = Object.new
      def obj.root; @root; end
      def obj.analyzed_state; @state; end
      def obj.input_metadata; @meta; end
      obj.instance_variable_set(:@root, schema_root)
      obj.instance_variable_set(:@state, state)
      obj.instance_variable_set(:@meta, input_metadata)
      obj
    end
  end
end
```

## Important Notes

1. **The parser already supports imports** - no changes needed to SchemaBuilder or Parser
2. **The DSL blocks work fine** - we just need to define modules that can be referenced
3. **Keep it simple** - don't overcomplicate the fixture infrastructure
4. **Use existing patterns** - follow how `analyzer_state_helper.rb` and `pass_test_helper.rb` work
5. **Test isolation** - golden schema modules should be reloadable for each test

## Related Files
- `lib/kumi/core/ruby_parser/schema_builder.rb` - has `import` method (already works)
- `lib/kumi/syntax/import_declaration.rb` - AST node for imports (already works)
- `lib/kumi/syntax/import_call.rb` - AST node for fn() calls (already works)
- `lib/kumi/core/analyzer/passes/normalize_to_nast_pass.rb` - handles ImportCall substitution (already works)
- `spec/kumi/analyzer_imports_phase*.rb` - unit tests (all passing)
- `spec/support/analyzer_state_helper.rb` - how to analyze schemas in tests (use as reference)
