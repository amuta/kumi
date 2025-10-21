# Schema Imports Implementation Plan

## Global Vision

Schema imports enable **reusing declarations across schemas** by importing them and calling them with different input mappings.

```kumi
import :total, from: Schemas::Tax

value :order_total, total(amount: input.price)
```

The computation `total` from Tax schema gets **inlined with substituted inputs**, as if we had written:
```kumi
value :order_total, input.price + (input.price * 0.15)
```

---

## Pipeline Transformation Overview

### Parse Phase
```
schema block
    ↓
Parser.parse(&block)
    ↓
ImportDeclaration nodes (AST)
ImportCall nodes (AST)
    ↓
Root(inputs, values, traits, imports)
```

### Analyzer Phase (DEFAULT_PASSES)
```
AST
    ↓
NameIndexer
  - Register local declarations
  - Register imports as lazy references
    ↓
InputCollector
    ↓
InputFormSchemaPass
    ↓
DeclarationValidator
    ↓
SemanticConstraintValidator
    ↓
DependencyResolver
  - Handle ImportCall nodes
  - Build import dependency edges
    ↓
Toposorter
    ↓
InputAccessPlannerPass
    ↓
NAST (still has ImportCall nodes)
```

### Analyzer Phase (HIR_TO_LIR_PASSES)
```
NAST + ImportCall
    ↓
NormalizeToNASTPass
    ↓
ConstantFoldingPass
    ↓
NASTDimensionalAnalyzerPass
  - **CRITICAL**: Handle ImportCall substitution here
  - Load source schema AST
  - Build substitution map (source input fields → caller expressions)
  - Re-analyze source declaration with substitutions
  - Replace ImportCall with substituted computation in NAST
    ↓
SNASTPass
  - Now SNAST has NO ImportCall nodes
  - All imports are inlined/substituted
    ↓
[Rest of pipeline unchanged]
    ↓
LIR (fully expanded, no import references)
    ↓
Codegen (Ruby/JS with inlined computations)
```

### Key Insight: ImportCall → Substituted Computation
- **Before NASTDimensionalAnalyzerPass:** ImportCall nodes present
- **After NASTDimensionalAnalyzerPass:** ImportCall nodes replaced with inlined AST
- **In SNAST onwards:** No evidence of imports - fully resolved

---

## System Components

### 1. AST Layer

#### New Nodes

**lib/kumi/syntax/import_declaration.rb**
```ruby
module Kumi
  module Syntax
    ImportDeclaration = Struct.new(:names, :module_ref, :loc) do
      include Node
      def children = []
    end
  end
end
```

**lib/kumi/syntax/import_call.rb**
```ruby
module Kumi
  module Syntax
    ImportCall = Struct.new(:fn_name, :input_mapping, :loc) do
      include Node
      def children = input_mapping.values
    end
  end
end
```

#### Modified Nodes

**lib/kumi/syntax/root.rb**
- Add `imports` field: `Root.new(:inputs, :values, :traits, :imports)`

#### Updated Exports

**lib/kumi/core/export/node_builders.rb**
- Add builders for ImportDeclaration, ImportCall

**lib/kumi/core/export/node_serializers.rb**
- Add serializers for ImportDeclaration, ImportCall

---

### 2. Parser Layer

**lib/kumi/core/ruby_parser/build_context.rb**
```ruby
class BuildContext
  def initialize
    @inputs = []
    @values = []
    @traits = []
    @imports = []  # NEW
    @imported_names = Set.new  # NEW
    # ...
  end

  attr_accessor :imports, :imported_names
end
```

**lib/kumi/core/ruby_parser/schema_builder.rb**

New methods:
```ruby
def import(*names, from:)
  validate_import_args(names, from)
  import_decl = Kumi::Syntax::ImportDeclaration.new(names, from, loc: @context.current_location)
  @context.imports << import_decl
  @context.imported_names.update(names)
end

def fn(fn_name, *args, **kwargs)
  if args.empty? && !kwargs.empty? && @context.imported_names.include?(fn_name)
    # ImportCall
    mapping = ExpressionConverter.new(@context).ensure_syntax_hash(kwargs)
    Kumi::Syntax::ImportCall.new(fn_name, mapping, loc: @context.current_location)
  else
    # Normal CallExpression or error
    # ...
  end
end
```

**lib/kumi/core/ruby_parser/parser.rb**
```ruby
def build_syntax_tree
  Root.new(@context.inputs, @context.values, @context.traits, @context.imports)
end
```

---

### 3. Name Indexing & Resolution

**lib/kumi/core/analyzer/passes/name_indexer.rb**

```ruby
class NameIndexer < PassBase
  def run(errors)
    definitions = {}
    imported_declarations = {}

    # Phase 1: Register imports as lazy references
    schema.root.imports.each do |import_decl|
      import_decl.names.each do |name|
        imported_declarations[name] = {
          type: :import,
          from_module: import_decl.module_ref,
          loc: import_decl.loc
        }
      end
    end

    # Phase 2: Index local declarations
    each_decl do |decl|
      if definitions.key?(decl.name) || imported_declarations.key?(decl.name)
        report_error(errors, "duplicated definition `#{decl.name}`", location: decl.loc)
      end
      definitions[decl.name] = decl
    end

    state.with(:declarations, definitions.freeze)
         .with(:imported_declarations, imported_declarations.freeze)
  end
end
```

**lib/kumi/core/analyzer/passes/import_analysis_pass.rb** (NEW)

```ruby
class ImportAnalysisPass < PassBase
  # RESPONSIBILITY: Load source schemas and extract imported declarations
  # PRODUCES: :imported_schemas - Cached source schema info

  def run(errors)
    imported_decls = get_state(:imported_declarations)
    imported_schemas = {}

    imported_decls.each do |name, meta|
      source_module = meta[:from_module]

      begin
        # Load source schema
        source_schema = source_module.kumi_schema_instance
        unless source_schema
          raise KeyError, "#{source_module} is not a Kumi schema"
        end

        # Find declaration in source
        source_decl = source_schema.root.values.find { |v| v.name == name } ||
                      source_schema.root.traits.find { |t| t.name == name }

        unless source_decl
          report_error(errors,
            "imported definition `#{name}` not found in #{source_module}",
            location: meta[:loc])
          next
        end

        # Cache source info
        imported_schemas[name] = {
          decl: source_decl,
          source_module: source_module,
          source_schema: source_schema,
          source_input_schema: source_schema.input_metadata
        }
      rescue => e
        report_error(errors,
          "failed to load import `#{name}` from #{source_module}: #{e.message}",
          location: meta[:loc])
      end
    end

    state.with(:imported_schemas, imported_schemas.freeze)
  end
end
```

**Update analyzer.rb to include ImportAnalysisPass**

Insert after NameIndexer in DEFAULT_PASSES:
```ruby
DEFAULT_PASSES = [
  NameIndexer,
  ImportAnalysisPass,  # NEW
  InputCollector,
  # ...
]
```

---

### 4. Dependency Resolution

**lib/kumi/core/analyzer/passes/dependency_resolver.rb**

Handle ImportCall nodes:
```ruby
def process_node(node, decl, graph, reverse_deps, leaves, definitions, input_meta, errors, context)
  case node
  when ImportCall
    # Validate imported function exists
    unless definitions.key?(node.fn_name)
      report_error(errors,
        "undefined import reference `#{node.fn_name}`", location: node.loc)
    end

    # Add dependency edge
    add_dependency_edge(graph, reverse_deps, decl.name, node.fn_name, :import_call, context[:via])

    # Trace dependencies through input mapping expressions
    node.input_mapping.each_value do |expr|
      visit_with_context(expr, context) do |n, ctx|
        process_node(n, decl, graph, reverse_deps, leaves, definitions, input_meta, errors, ctx)
      end
    end

  when DeclarationReference
    # ... existing code
  end
end
```

---

### 5. Type Analysis & Substitution (Critical!)

**lib/kumi/core/analyzer/passes/nast_dimensional_analyzer_pass.rb**

```ruby
class NASTDimensionalAnalyzerPass < PassBase
  def run(errors)
    # ... existing code ...

    # NEW: Register handler for ImportCall
    @import_schemas = get_state(:imported_schemas)
  end

  # NEW: Handle ImportCall nodes
  def visit_import_call(node, context)
    import_meta = @import_schemas[node.fn_name]

    unless import_meta
      raise "ImportCall for `#{node.fn_name}` not found in imported_schemas"
    end

    # Step 1: Analyze input mapping expressions in caller context
    caller_input_stamps = {}
    node.input_mapping.each do |param_name, expr|
      caller_input_stamps[param_name] = visit(expr, context)
    end

    # Step 2: Build substitution map
    # Map: source input field name → (caller expression, its stamp)
    source_input_schema = import_meta[:source_input_schema]
    substitution_map = build_substitution_map(
      source_input_schema,
      node.input_mapping,
      caller_input_stamps
    )

    # Step 3: Re-analyze source declaration with substitution
    source_decl = import_meta[:decl]
    result_stamp = visit_with_substitution(source_decl.expression, substitution_map, context)

    return result_stamp
  end

  private

  def build_substitution_map(source_input_schema, input_mapping, caller_input_stamps)
    # Creates a map: {source_field_name => {expr: caller_expr, stamp: caller_stamp}}
    map = {}
    input_mapping.each do |param_name, caller_expr|
      source_field = source_input_schema.find { |f| f.name == param_name }

      unless source_field
        raise "Source input field `#{param_name}` not found"
      end

      map[param_name] = {
        expr: caller_expr,
        stamp: caller_input_stamps[param_name]
      }
    end
    map
  end

  def visit_with_substitution(node, substitution_map, context)
    case node
    when InputReference
      # Replace with caller's expression
      substitute_input_ref(node, substitution_map, context)

    when InputElementReference
      # Replace with caller's expression
      substitute_input_element_ref(node, substitution_map, context)

    when DeclarationReference
      # Local reference within source - shouldn't happen in isolation
      # but might if source had nested calls
      visit(node, context)

    when CallExpression
      # Visit arguments with substitution context
      args_stamps = node.args.map { |arg| visit_with_substitution(arg, substitution_map, context) }
      # Perform type inference for the call with substituted args
      infer_call_type(node.fn_name, args_stamps)

    when CascadeExpression
      # Visit cases with substitution
      # ... handle cascade ...

    else
      # Leaf nodes (Literal, etc)
      visit(node, context)
    end
  end

  def substitute_input_ref(node, substitution_map, context)
    sub = substitution_map[node.name]
    unless sub
      raise "Input field `#{node.name}` not mapped in ImportCall"
    end
    # Return the caller's expression's stamp (already computed)
    sub[:stamp]
  end

  def substitute_input_element_ref(node, substitution_map, context)
    # node.path = [:field1, :field2, :value]
    root_field = node.path.first
    sub = substitution_map[root_field]

    unless sub
      raise "Root input field `#{root_field}` not mapped in ImportCall"
    end

    # The caller's expression already has its shape
    # If it's an array, this element access continues to work
    sub[:stamp]
  end
end
```

---

### 6. SNAST Generation

**lib/kumi/core/analyzer/passes/snast_pass.rb**

No changes needed! After NASTDimensionalAnalyzerPass, ImportCall nodes are gone and replaced with substituted computations. SNASTPass sees only normal CallExpression nodes.

---

### 7. Later Passes

**UnsatDetector, OutputSchemaPass, etc.**
- No changes needed - work on fully resolved SNAST

---

### 8. LIR Generation

**lib/kumi/core/analyzer/passes/lower_to_irv2_pass.rb**
- No special handling needed - ImportCalls are already gone
- LIR sees fully substituted/inlined computations

---

### 9. Codegen

**lib/kumi/core/ruby_target/ruby_pass.rb**
- No special handling needed - generates code for inlined computations

---

## Implementation Roadmap (TDD)

### Phase 1: AST & Parser (RED-GREEN-REFACTOR)

**Files:**
- Create `lib/kumi/syntax/import_declaration.rb`
- Create `lib/kumi/syntax/import_call.rb`
- Modify `lib/kumi/syntax/root.rb`
- Modify `lib/kumi/core/ruby_parser/build_context.rb`
- Modify `lib/kumi/core/ruby_parser/schema_builder.rb`
- Modify `lib/kumi/core/ruby_parser/parser.rb`
- Update export layer (node_builders, serializers)

**Test:** `spec/kumi/parser_imports_spec.rb`
```ruby
it "parses import declaration" do
  ast = parse_schema do
    import :tax, from: Schemas::Tax
    input { decimal :amount }
    value :result, ref(:tax)
  end

  expect(ast.imports.size).to eq(1)
  expect(ast.imports[0].names).to eq([:tax])
end

it "parses import call with named arguments" do
  ast = parse_schema do
    import :tax, from: Schemas::Tax
    input { decimal :price }
    value :result, fn(:tax, amount: ref(:input).price)
  end

  value_decl = ast.values[0]
  expect(value_decl.expression).to be_a(Kumi::Syntax::ImportCall)
  expect(value_decl.expression.fn_name).to eq(:tax)
  expect(value_decl.expression.input_mapping.keys).to eq([:amount])
end
```

---

### Phase 2: Name Indexing (RED-GREEN-REFACTOR)

**Files:**
- Modify `lib/kumi/core/analyzer/passes/name_indexer.rb`
- Create `lib/kumi/core/analyzer/passes/import_analysis_pass.rb`
- Modify `lib/kumi/analyzer.rb` to add ImportAnalysisPass

**Test:** `spec/kumi/analyzer_imports_phase1_spec.rb`
```ruby
it "registers imported declarations" do
  # Mock source schema
  source_schema = build_source_schema do
    value :tax, "input.amount * 0.15"
  end

  allow(Schemas::Tax).to receive(:kumi_schema_instance).and_return(source_schema)

  ast = parse_schema do
    import :tax, from: Schemas::Tax
    input { decimal :amount }
    value :result, ref(:tax)
  end

  state = analyze_to_pass(ast, :name_indexer)
  expect(state.imported_declarations.keys).to include(:tax)

  state = analyze_to_pass(ast, :import_analysis)
  expect(state.imported_schemas.keys).to include(:tax)
end
```

---

### Phase 3: Dependency Resolution (RED-GREEN-REFACTOR)

**Files:**
- Modify `lib/kumi/core/analyzer/passes/dependency_resolver.rb`

**Test:** `spec/kumi/analyzer_imports_phase2_spec.rb`
```ruby
it "traces import call dependencies" do
  # ... setup ...

  state = analyze_to_pass(ast, :dependency_resolver)
  deps = state.dependencies[:result]
  expect(deps.map(&:to)).to include(:tax)
end
```

---

### Phase 4: Type Analysis & Substitution (RED-GREEN-REFACTOR) ⭐

**Files:**
- Modify `lib/kumi/core/analyzer/passes/nast_dimensional_analyzer_pass.rb`

**Test:** `spec/kumi/analyzer_imports_phase3_spec.rb`
```ruby
it "substitutes inputs and derives correct type stamp" do
  # Source: value :tax, input.amount * 0.15
  # Caller: value :result, tax(amount: input.price)
  # Expected: result stamp = [] -> decimal

  state = analyze_to_pass(ast, :nast_dimensional_analyzer)

  tax_result = get_snast_value(state, :result)
  # Should show substituted computation
  expect(tax_result).to_not be_a(ImportCall)
  expect(tax_result.expression).to match_computation("input.price * 0.15")
end

it "broadcasts with array arguments" do
  # Caller passes array
  # value :results, tax(amount: input.items.item.price)
  # Expected: result stamp = [items] -> decimal

  state = analyze_to_pass(ast, :nast_dimensional_analyzer)
  result_stamp = state.snast_module.values[:results].stamp
  expect(result_stamp.dimensions).to eq([:items])
end
```

---

### Phase 5: Integration & End-to-End (RED-GREEN-REFACTOR)

**Files:**
- No new files needed
- Golden test

**Test:** `spec/golden/schema_imports_basic.kumi`
```kumi
# Source: Schemas::Tax schema
# Source input: {amount: decimal}
# Source value: tax = input.amount * 0.15

# Caller
schema do
  import :tax, from: Schemas::Tax

  input do
    decimal :price
  end

  value :result, tax(amount: input.price)
end

# Expected output: {result: decimal}
# For input {price: 100}, result = 100 * 0.15 = 15
```

**Test:** `spec/golden/schema_imports_broadcasting.kumi`
```kumi
# Source: Schemas::Discount schema
# Source input: {price: decimal}
# Source value: discounted = price * 0.8

# Caller
schema do
  import :discounted, from: Schemas::Discount

  input do
    array :items do
      hash :item do
        decimal :price
      end
    end
  end

  value :results, discounted(price: input.items.item.price)
end

# Expected: [items] -> decimal broadcasts correctly
```

---

## Error Handling

### Parse Time
- Import outside schema block: raise SyntaxError
- Invalid `from:` reference: raise SyntaxError
- ImportCall with positional args: raise SyntaxError

### Name Indexing
- Duplicate import name + local name: raise SemanticError
- Import not found in source: raise SemanticError

### Type Analysis
- Missing input field mapping: raise SemanticError
- Type mismatch between mapped arg and expected input field: raise SemanticError
- Circular imports: raise SemanticError

---

## Summary of Changes by Component

| Component | Change | Rationale |
|-----------|--------|-----------|
| AST | +ImportDeclaration, +ImportCall | New node types |
| Parser | +import() method, updated fn() | Parse new syntax |
| NameIndexer | +import registration | Lazy resolution |
| NEW | ImportAnalysisPass | Load source schemas |
| DependencyResolver | +ImportCall handler | Build dependency edges |
| NASTDimensionalAnalyzer | +ImportCall visitor, +substitution | **Critical**: inline + type-check |
| SNAST onwards | No changes | Fully resolved AST |
| Export layer | +serializers | Support export |

---

## The "No Input Keywords" Key Principle

When parsing `tax(amount: input.price)`:
- All arguments are **kwargs**
- Kwargs names match **source schema's input field names**
- This is the implicit mapping - no explicit `input:` keyword needed
- Parser recognizes it's an ImportCall if: fn_name in imported_names ✓ && all args are kwargs ✓

---

## Testing Strategy

1. **Unit tests:** Each pass in isolation with mocked state
2. **Integration tests:** Full analyzer pipeline with realistic schemas
3. **Golden tests:** End-to-end compiled + executed schemas
4. **Error tests:** All error conditions caught gracefully

Each phase builds incrementally, nothing broken until complete.
