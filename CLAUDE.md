# Important
Ignore Linting issues for now.

# Vector Semantics
Axes align by identity (lineage), not by name

# Analyzer
> lib/kumi/analyzer.rb
> lib/kumi/core/analyzer/passes/pass_base.rb

# Debug Tools:
`bin/kumi pp <ast|nast|snast|ir> <schema>` - Pretty print representations
`bin/kumi analyze <schema> --dump <state_key>` - Dump analyzer state (call_table, declaration_table, snast_module, etc.)
`bin/kumi golden list` - List all golden test schemas
`bin/kumi golden record [name]` - Record expected representations
`bin/kumi golden verify [name]` - Verify current vs expected
`bin/kumi golden diff <name>` - Show diffs when verification fails

# Kernels Invariants
All reducers are pure binary combiner f : T × T → T applied over the last axis of a value. Example: agg.sum(a,b) = a+b.


# KernelRegistry:
You can use the KernelRegistry like this:
> registry = Kumi::KernelRegistry.load_ruby
> registry.impl_for("agg.sum:ruby:v1")
=> "->(a,b) {a + b}"





