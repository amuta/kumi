# Analyzer Pass Debugging

**Pattern:** `PassClassName` → `DEBUG_PASS_CLASS_NAME=1`

```bash
# InputIndexTablePass
DEBUG_INPUT_INDEX_TABLE=1 bin/kumi analyze schema.kumi

# ScopeResolutionPass  
DEBUG_SCOPE_RESOLUTION=1 bin/kumi analyze schema.kumi

# Multiple passes
DEBUG_INPUT_INDEX_TABLE=1 DEBUG_SCOPE_RESOLUTION=1 bin/kumi analyze schema.kumi
```

**In passes:**
```ruby
class MyPass < PassBase
  def run(errors)
    debug "Processing #{items.size} items"
  end
end
```

**Output:**
```
[My] Processing 5 items
```