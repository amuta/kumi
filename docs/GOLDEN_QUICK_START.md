# Golden Tests: Quick Start

## 30-Second Summary

A golden test verifies that a Kumi schema compiles correctly and produces expected output.

**Structure:**
```
golden/my_test/
├── schema.kumi        # Your schema
├── input.json         # Test input
├── expected.json      # Expected output
└── expected/          # Generated intermediate files (auto-created)
```

**Workflow:**
```bash
# 1. Create files
mkdir -p golden/my_test
# Write schema.kumi, input.json, expected.json

# 2. Generate expected outputs
bin/kumi golden update my_test

# 3. Test it
bin/kumi golden test my_test

# 4. Done!
git add golden/my_test/
```

## Common Commands

| What | Command |
|------|---------|
| List all tests | `bin/kumi golden list` |
| Run one test | `bin/kumi golden test test_name` |
| Run all tests | `bin/kumi golden test` |
| Generate expected files | `bin/kumi golden update test_name` |
| See what changed | `bin/kumi golden diff test_name` |

## File Templates

### schema.kumi
```ruby
schema do
  input do
    # Define input fields
    integer :age
    float :salary
  end

  # Define outputs
  value :result, input.age * 2
end
```

### input.json
```json
{
  "age": 30,
  "salary": 50000.0
}
```

### expected.json
```json
{
  "result": 60
}
```

## Example: Age Eligibility Test

```bash
# 1. Create directory
mkdir -p golden/age_eligibility

# 2. Create schema.kumi
cat > golden/age_eligibility/schema.kumi << 'EOF'
schema do
  input do
    integer :age
  end

  value :can_vote, input.age >= 18
  value :can_drink, input.age >= 21
  value :senior, input.age >= 65
end
EOF

# 3. Create input.json
cat > golden/age_eligibility/input.json << 'EOF'
{
  "age": 25
}
EOF

# 4. Create expected.json
cat > golden/age_eligibility/expected.json << 'EOF'
{
  "can_vote": true,
  "can_drink": true,
  "senior": false
}
EOF

# 5. Generate expected representations
bin/kumi golden update age_eligibility

# 6. Test
bin/kumi golden test age_eligibility
```

Expected output:
```
✓ age_eligibility: PASS
```

## Tips

1. **Keep it simple** - One feature per test
2. **Use round numbers** - Makes verification easier (25, 100, 50.0)
3. **Check generated code** - Review `expected/schema_ruby.rb`
4. **Test edge cases** - Null, zero, negative values
5. **Write clear names** - `cascade_logic`, `array_operations`, not `test1`

## Common Issues

| Issue | Solution |
|-------|----------|
| "Output doesn't match" | Verify expected.json calculation by hand |
| "Schema fails to compile" | Check schema.kumi syntax |
| "File not found" | Make sure you're in `golden/` directory |
| "No such subcommand" | Use `bin/kumi golden test` not `bin/kumi verify` |

## Next Steps

- Read [GOLDEN_TESTS.md](GOLDEN_TESTS.md) for detailed guide
- Check existing tests: `ls golden/`
- Create your first test!
