# CLAUDE.md

!! Important:
!! Remember, this gem is not on production yet, so no backward compatilibity is necessary. But do not change the public interfaces (e.g. DSL, Schema) without explicitly requested or demanded. 
!! We are using zeitwerk, i.e.: no requires
!! Disregard linting or coverage issues unless asked to do so.
!! Communication style - Write direct, factual statements. Avoid promotional language, unnecessary claims, or marketing speak. State what the system does, not what benefits it provides. Use TODOs for missing information rather than placeholder claims.
!! See all Available Functions in docs/FUNCTIONS.md

## Project Overview

**Kumi** is a declarative rules-and-calculation DSL for Ruby. It compiles business logic into a **typed, analyzable dependency graph** with **vector semantics** over nested data, performs **static checks** at definition time, **lowers to a compact IR**, and executes **deterministically**

### Key Patterns
**DSL Structure**:
```ruby
schema do
  input do
    # Recommended type-specific DSL methods
    string  :field_name
    integer :number_field, domain: 0..100
    array   :scores, elem: { type: :float }
    hash    :metadata, key: { type: :string }, val: { type: :any }

    array :line_items do
      float   :price
      integer :quantity
      string  :category
    end

    # Fields with no declared type
    any     :misc_field
  end

  trait :name, (expression)  # Boolean conditions
  value :name, expression    # Computed values
  value :name do             # Conditional logic
    on trait_x, result     # on <trait> ?,<trait> , <expr>
    on trait_y, trait_z, (expression) # expression can be just a reference to a value
    base default_result      # base <expr>
  end
end
```

## Development Commands

### Testing
- `bundle exec rspec` - Run all tests
- `bundle exec rspec spec/path/to/specific_spec.rb` - Run specific test file
- `bundle exec rspec spec/path/to/specific_spec.rb:123` - Run specific test at line
- `./scripts/analyze_test_failures.rb` - Comprehensive test failure analysis with intelligent grouping

### Test Helpers
**AnalyzerStateHelper** (`spec/support/analyzer_state_helper.rb`):
- `analyze_up_to(state_name) { schema }` - Run analyzer up to specific pass
- Available states: `:name_index`, `:input_metadata`, `:dependencies`, `:evaluation_order`, `:cascade_validated`, `:cascade_desugared`, `:broadcasts`, `:types_inferred`, `:ir_module`
- Example: `state = analyze_up_to(:broadcasts) { input { array :items { float :price } }; value :total, fn(:sum, input.items.price) }`

## Architecture Overview

### Core Components

**Schema System** (`lib/kumi/schema.rb`):
- Entry point that ties together parsing, analysis, and compilation
- DSL method `schema(&block)` builds the syntax tree, runs analysis, and compiles to executable form
- Generates a `Runner` instance for executing queries against input data

**Parser** (`lib/kumi/ruby_parser{/*,.rb}`):

**Syntax Tree** (`lib/kumi/syntax/`):
- `node.rb` - Base node class with location tracking
- `root.rb` - Root schema node containing inputs, attributes, and traits
- `value_declaration.rb` - Value declaration nodes (formerly Attribute)
- `trait_declaration.rb` - Trait declaration nodes (formerly Trait)
- `input_declaration.rb` - Input field declaration nodes (formerly FieldDecl)
- `call_expression.rb` - Function call expression nodes
- `array_expression.rb` - Array expression nodes (formerly ListExpression)
- `hash_expression.rb` - Hash expression nodes (for future hash literals) (currently not used)
- `cascade_expression.rb` - Cascade expression nodes (conditional values)
- `case_expression.rb` - Case expression nodes (formerly WhenCaseExpression)
- `literal.rb` - Literal value nodes
- `input_reference.rb` - Input field reference nodes (formerly FieldRef) 
- `input_element_reference.rb` - Reference to nested input field (array -> obj.field) 
- `declaration_reference.rb` - Declaration reference value or trait nodes

**Analyzer** (`lib/kumi/analyzer.rb`):
(passes in `lib/kumi/core/analyzer/passes/`)
- NameIndexer,                     # 1. Finds all names and checks for duplicates.
- InputCollector,                  # 2. Collects field metadata from input declarations.
- DeclarationValidator,            # 3. Checks the basic structure of each rule.
- SemanticConstraintValidator,     # 4. Validates DSL semantic constraints at AST level.
- DependencyResolver,              # 5. Builds the dependency graph with conditional dependencies.
- UnsatDetector,                   # 6. Detects unsatisfiable constraints and analyzes cascade mutual exclusion.
- Toposorter,                      # 7. Creates the final evaluation order, allowing safe cycles.
- CascadeConstraintValidator,      # 8. Validates cascade_and usage constraints.
- CascadeDesugarPass,              # 9. Desugar cascade_and to regular and operations.
- CallNameNormalizePass,           # 10. Normalize function names to canonical basenames.
- BroadcastDetector,               # 11. Detects which operations should be broadcast over arrays.
- TypeInferencerPass,              # 12. Infers types for all declarations (uses vectorization metadata).
- TypeConsistencyChecker,          # 13. Validates declared vs inferred type consistency.
- FunctionSignaturePass,           # 14. Resolves NEP-20 signatures for function calls.
- TypeCheckerV2,                   # 15. Computes CallExpression result dtypes and validates constraints via RegistryV2.
- AmbiguityResolverPass,           # 16. Resolves ambiguous functions using complete type information.
- InputAccessPlannerPass,          # 17. Plans access strategies for input fields.
- ScopeResolutionPass,             # 18. Plans execution scope and lifting needs for declarations.
- ContractCheckPass,               # 19. Validates analyzer state contracts.
- JoinReducePlanningPass,          # 20. Plans join/reduce operations and stores in node_index (Generates IR Structs)
- LowerToIRPass                    # 21. Lowers the schema to IR (Generates IR Structs)


**Compiler** (`lib/kumi/compiler.rb`):
Basicaly ->  Runtime::Executable.from_analysis(@analysis.state, registry: function_registry)

**Function Registry** (`lib/kumi/core/functions/registry_v2.rb`):
- **RegistryV2**: Modern YAML-based function registry with NEP-20 signature support
- Qualified function names: `core.gt`, `core.add`, `agg.sum`, `agg.max`, etc.
- Function classes: `:scalar`, `:aggregate`, `:structure`, `:vector`
- Supports arity-based resolution and signature metadata


**IMPORTANT CASCADE CONDITION SYNTAX:**
In cascade expressions (`value :name do ... end`), trait references use bare identifiers:

**FORBIDDEN FUNCTIONS:**
- `cascade_and` is pure syntax sugar, NOT a callable function via `fn(:cascade_and, ...)`
- Only appears in cascade expression conditions and gets desugared by analyzer passes
- Use regular boolean operators (`&`, `|`) or separate traits for AND/OR logic

**Expression Types**:
- `input.field_name` - Access input data with operator methods (>=, <=, >, <, ==, !=)
- `ref(:name)` - Reference other declarations
- `fn(:name, args...)` - Function calls
- `(expr1) & (expr2)` - Logical AND chaining
- `[element1, element2]` - Lists
- Literals (numbers, strings, booleans)

**Analysis Flow**:
1. Parse DSL → Syntax Tree
2. Analyze Syntax Tree → Analysis Result (dependency graph, type information, topo order)
3. Compile → Executable Schema  
4. Execute with Runner

**Type System** (`lib/kumi/types.rb`):
- Symbol-based type system
- **Dual Type System**: Declared types (from input blocks) and inferred types (from expressions)
- Type inference for all declarations based on expression analysis
- Type primitives: `:string`, `:integer`, `:float`, `:boolean`, `:any`, `:symbol`, `:regexp`, `:time`, `:date`, `:datetime`
- Collection types: `array(:element_type)` and `hash(:key_type, :value_type)` helper functions

## Files for Understanding

. `docs/*` - Documents about Kumi, its features, DSL syntax, ... 
- `examples/*` Random examples of diverse contexts.

### Troubleshooting Schema Issues

**Debug Environment Variables:**
- `DEBUG_NORMALIZE=1` - Show function name normalization (raw → qualified)
- `DEBUG_CASCADE=1` - Show cascade_and desugar operations  
- `DEBUG_TYPE_CHECKER=1` - Show function signature validation
- `DEBUG_BROADCAST=1` - Show broadcast detection and function classes
- `DEBUG_LOWER=1` - Show IR lowering and kernel selection
- `DEBUG_SCOPE_RESOLUTION=1` - Show scope inference and propagation

**Debug Output Format:**
All passes use standardized debug output with `call_id=object_id` for tracing:
```
CascadeDesugar call_id=12345 args=1 desugar=identity skip_signature=true
Normalized call_id=12345 raw=> effective=> qualified=core.gt  
TypeCheck call_id=12345 qualified=core.gt fn_class=scalar status=validated
```


### Array Broadcasting System

**Vectorization**: Field access on array inputs (`input.items.price`) applies operations element-wise with map/reduce detection.

**Basic Broadcasting**:
```ruby
input do
  array :line_items do
    float   :price
    integer :quantity  
    string  :category
    array   :prices do
      element :integer, :val
    end
  end
end

# Element-wise computation - broadcasts over each item
value :subtotals, input.line_items.price * input.line_items.quantity
trait :is_taxable, (input.line_items.category != "digital")
```
