# SynthesizeAccessChains Pass Implementation Plan

## Problem Analysis

**Current Issue**: 
- `LowerToIRV2Pass.collect_declaration_parameters` manually reconstructs input parameters from LoadInput operations
- This creates coupling between IR generation and parameter extraction
- JSON export needs consistent canonical input plans

**Current Flow**:
```
access_plans (multiple modes per path) → LowerToIRV2Pass → collect_declaration_parameters → JSON export
```

**Desired Flow**:
```
access_plans → SynthesizeAccessChains → ir_input_plans → LowerToIRV2Pass → JSON export
```

## SynthesizeAccessChains Pass

**Location**: Before `LowerToIRV2Pass` in `SIDE_TABLE_PASSES` (lib/kumi/analyzer.rb:36)

**Input/Output**:
- Input: `state[:access_plans]` (multiple plans per path, different modes)
- Input: `state[:input_table]` (for dtype lookup)
- Output: `state[:ir_input_plans]` (one plan per unique input path)

**Selection Logic**: 
For each unique path in access_plans:
- Choose `:read` mode if available
- Otherwise choose `:each_indexed` mode

**Canonical Plan Format**:
```ruby
{
  type: "input",
  name: "in_#{path.last}",                    # e.g., "in_x", "in_employees"
  path: path.split('.').map(&:to_sym),        # e.g., [:employees, :salary]  
  axes: selected_plan.containers,             # from selected access plan
  dtype: input_table[path_array][:dtype]      # lookup from input_table
}
```

**Expected JSON Output**:
```json
"parameters": [
  {
    "type": "input",
    "name": "in_x", 
    "path": ["x"],
    "axes": [],
    "dtype": "integer"
  }
]
```

## Implementation Files

1. **Create**: `lib/kumi/core/analyzer/passes/synthesize_access_chains_pass.rb`
2. **Update**: `lib/kumi/analyzer.rb` (add to SIDE_TABLE_PASSES)
3. **Update**: `lib/kumi/core/analyzer/passes/lower_to_irv2_pass.rb` (use canonical plans)

## Integration Benefits

- Clean separation: access chain synthesis happens once
- Both IR generation and JSON export use same canonical representation
- Eliminates redundant parameter reconstruction in LowerToIRV2Pass
