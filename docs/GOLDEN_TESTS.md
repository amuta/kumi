# Golden Tests Guide

Golden tests verify schema compilation and execution correctness across all stages: parsing → code generation → execution.

## Structure

A golden test contains:
- **schema.kumi** - Schema under test
- **input.json** - Test input data
- **expected.json** - Expected execution output
- **expected/** - Generated intermediate representations (AST, NAST, SNAST, LIR, codegen)

```
golden/my_test/
├── schema.kumi
├── input.json
├── expected.json
└── expected/
    ├── ast.txt
    ├── nast.txt
    ├── snast.txt
    ├── schema_ruby.rb
    ├── schema_javascript.mjs
    └── lir_*.txt
```

## Creating a Golden Test

### Step 1: Plan
What feature? Complexity level? Edge cases?

### Step 2: Create directory
```bash
mkdir -p golden/my_test
```

### Step 3: Write schema.kumi
```ruby
schema do
  input do
    integer :age
    float :salary
  end

  value :adjusted, input.salary * 1.05
end
```

Keep schemas focused on one feature (10-30 lines).

### Step 4: Create input.json
```json
{
  "age": 30,
  "salary": 100000.0
}
```

Use realistic, round numbers for easy verification.

### Step 5: Create expected.json
```json
{
  "adjusted": 105000.0
}
```

Calculate by hand first. Verify math.

### Step 6: Generate representations
```bash
bin/kumi golden update my_test
```

This creates `expected/` with all intermediate files.

### Step 7: Test
```bash
bin/kumi golden test my_test
```

Expected: `✓ my_test: PASS`

## Commands

| Command | Purpose |
|---------|---------|
| `bin/kumi golden list` | List all tests |
| `bin/kumi golden update [name]` | Generate expected files |
| `bin/kumi golden test [name]` | Run test |
| `bin/kumi golden diff [name]` | See changes |

Use multiple names: `bin/kumi golden test test1 test2`

## Common Issues

**"Output doesn't match"**
- Recalculate expected.json by hand
- Check input.json values
- Regenerate: `bin/kumi golden update my_test`

**"Schema fails to compile"**
```bash
bin/kumi analyze golden/my_test/schema.kumi
```

**"Generated code is wrong"**
```bash
cat golden/my_test/expected/schema_ruby.rb
cat golden/my_test/expected/lir_00_unoptimized.txt
```

## Patterns

### Array Vectorization
When testing operations on arrays with multiple dimensions:

```ruby
schema do
  input do
    people: [{name: string, salary: float}]
    department: string
  end

  let total = fn(:sum, input.people.salary)
  value avg, total / fn(:size, input.people)
end
```

### Cascade Logic
```ruby
schema do
  input { age: integer }

  value category,
    on input.age < 18 do
      "youth"
    on input.age < 65 do
      "adult"
    base
      "senior"
end
```

### Error Handling
Schema compilation errors are caught at compile time:

```ruby
schema do
  input { age: integer }
  value invalid, unknown_function(input.age)
end
```

Result: `✗ invalid_function: SKIP (Compilation Error)`

## Best Practices

1. **Test one feature per schema** - Keep it focused
2. **Use descriptive names** - `cascade_logic`, not `test1`
3. **Round numbers** - Easier to verify by hand
4. **Review generated code** - Check `expected/schema_ruby.rb`
5. **Test edge cases** - Null, zero, negative values
6. **Commit to git** - Track all files including `expected/`

## Maintenance

### Update Expected Files

When behavior changes intentionally:

```bash
bin/kumi golden update my_test
git diff golden/my_test/expected/
# Review changes
git add golden/my_test/expected/
```

### View Differences

```bash
bin/kumi golden diff my_test
```

Shows side-by-side comparison of what changed.

## Example: Complete Workflow

Create `golden/eligibility/`:

**schema.kumi:**
```ruby
schema do
  input do
    integer :age
  end

  value :can_vote, input.age >= 18
  value :can_drink, input.age >= 21
end
```

**input.json:**
```json
{
  "age": 25
}
```

**expected.json:**
```json
{
  "can_vote": true,
  "can_drink": true
}
```

**Generate and test:**
```bash
bin/kumi golden update eligibility
bin/kumi golden test eligibility
```

Result: `✓ eligibility: PASS`

## Quick Troubleshooting

| Issue | Fix |
|-------|-----|
| "File not found" | Make sure you're in `golden/` directory |
| "Floating point mismatch" | Check precision in input/expected |
| "Test passes locally but fails in CI" | Look for non-deterministic IR generation |

## Next Steps

1. List existing tests: `bin/kumi golden list`
2. Review a simple one: `cat golden/simple_math/`
3. Create your first test following this guide
4. Verify it passes
5. Review generated code to understand compilation
