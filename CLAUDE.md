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

