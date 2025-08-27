# SNAST Pass

The Semantic NAST (SNAST) Pass takes the output from the NASTDimensionalAnalyzerPass and creates an annotated version of the NAST where every node contains dimensional and execution metadata.

## Purpose

Transform NAST into SNAST by adding semantic annotations to make IR lowering deterministic and mechanical.

## Input State

- `nast_module`: Normalized AST representation
- `call_table`: Function call metadata from dimensional analyzer
- `declaration_table`: Declaration metadata from dimensional analyzer  
- `input_table`: Input path metadata

## Output State

- `snast_module`: Semantic NAST with annotated nodes

## Node Annotations

Every SNAST node contains:

### Required Metadata
- `meta[:stamp] = {axes_tokens, dtype}`: Dimensional scope and data type
- `meta[:value_id]`: Stable identifier for IR lowering (e.g., "v1", "v2") 
- `meta[:topo_index]`: Topological ordering index

### Call Node Plans
Call nodes additionally contain `meta[:plan]`:

**Elementwise operations:**
```ruby
{
  kind: :elementwise,
  target_axes_tokens: [:regions, :offices, :teams],
  needs_expand_flags: [false, true, false]  # which args need broadcasting
}
```

**Reduce operations:**
```ruby
{
  kind: :reduce, 
  last_axis_token: :teams  # axis to drop
}
```

## Example Output

For a call like `input.departments.teams.headcount > 10`:

```ruby
# Original NAST Call node becomes:
call.meta[:stamp] = {
  axes_tokens: [:departments, :teams],
  dtype: :boolean
}
call.meta[:plan] = {
  kind: :elementwise,
  target_axes_tokens: [:departments, :teams], 
  needs_expand_flags: [false, true]  # constant 10 needs expansion
}
call.meta[:value_id] = "v3"
call.meta[:topo_index] = 5
```

## Usage

Test the SNAST pass output:
```bash
bin/kumi analyze golden/min_reduce_scope/schema.kumi --dump snast_module
```

This enables deterministic IR lowering where the lowering pass only needs to read the pre-computed stamps and plans rather than re-analyzing dimensional semantics.