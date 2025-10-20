# Important
Ignore Linting issues for now.
Dont invent backward compatibility unless that is the plan.

# Vector Semantics
Axes align by identity (lineage), not by name

# Analyzer
> lib/kumi/analyzer.rb
> lib/kumi/core/analyzer/passes/pass_base.rb

# For a schema.kumi
- To view a IRV2 `bin/kumi pp irv2 <schema.kumi>`

# Golden tests
- First udpate `bin/kumi golden update <empty for all | golden_name>` then `bin/kumi golden test <same>`



# Debug Tools:
`bin/kumi pp <ast|nast|snast|ir> <schema>` - Pretty print representations
`bin/kumi analyze <schema> --dump <state_key>` - Dump analyzer state (call_table, declaration_table, snast_module, etc.)
`bin/kumi golden list` - List all golden test schemas
`bin/kumi golden record [name]` - Record expected representations
`bin/kumi golden verify [name]` - Verify current vs expected
`bin/kumi golden diff <name>` - Show diffs when verification fails

# Documentation Generation
`bin/kumi-doc-gen` - Generate IDE-friendly JSON + Markdown docs from function/kernel definitions
See docs/DEVELOPMENT.md for details

# Kernels Invariants
All reducers are pure binary combiner f : T × T → T applied over the last axis of a value. Example: agg.sum(a,b) = a+b.


# KernelRegistry:
You can use the KernelRegistry like this:
> registry = Kumi::KernelRegistry.load_ruby
> registry.impl_for("agg.sum:ruby:v1")
=> "->(a,b) {a + b}"





