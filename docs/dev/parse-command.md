# Parse Command

One-command developer loop for text schemas: parse → analyze → render IR → diff.

## Usage

```bash
# Default: show diff vs golden file (or print if no golden)
kumi parse golden/simple_math/schema.kumi

# Write/overwrite golden file  
kumi parse golden/simple_math/schema.kumi --write

# Update golden only if different
kumi parse golden/simple_math/schema.kumi --update

# JSON format instead of text
kumi parse golden/simple_math/schema.kumi --json --write

# Enable state tracing
kumi parse golden/simple_math/schema.kumi --trace

# Snapshot analysis passes
kumi parse golden/simple_math/schema.kumi --snap after --snap-dir debug/
```

## Exit Codes

- `0` - No changes or successful write
- `1` - Diff mismatch or analysis error

## Output

**No changes:**
```
No changes (golden/simple_math/expected/ir.txt)
```

**Diff mismatch:**
```
--- expected
+++ actual
@@ -6,7 +6,7 @@
   2: map argc=2 fn=:add [0, 1]
+  2: map argc=2 fn=:power [0, 1]
```

**Write mode:**
```
Wrote: golden/simple_math/expected/ir.txt
```

## IR Format

Deterministic text representation:
```
IR Module
decls: 3
decl[0] value:sum shape=scalar ops=4
  0: load_input has_idx=false is_scalar=true plan_id=x:read scope=[] []
  1: load_input has_idx=false is_scalar=true plan_id=y:read scope=[] []
  2: map argc=2 fn=:add [0, 1]
  3: store name=:sum [2]
```