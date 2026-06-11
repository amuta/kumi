# Agent Reference

A toolbox for inspecting and debugging the compiler pipeline. The pipeline is
SNAST → DFIR → VecIR → LoopIR → Ruby/JS emitters; see
[ARCHITECTURE.md](ARCHITECTURE.md).

## Inspect One Layer for One Schema

```bash
bundle exec bin/kumi pp <repr> <schema.kumi>
# reprs: ast, input_plan, nast, snast, dfir, dfir_optimized, vecir, loopir,
#        schema_ruby, schema_javascript
bundle exec bin/kumi pp loopir golden/multi_loop_reduction/schema.kumi
```

This is the fastest way to surface a lowering crash in a specific layer.

## Sweep for Crashes

```bash
for d in golden/*/; do
  bundle exec bin/kumi pp loopir "$d/schema.kumi" >/dev/null || echo "$d"
done
```

## Phase-Scoped Golden Checks

```bash
bundle exec bin/kumi golden_v2 verify --repr loop            # one layer, all schemas
bundle exec bin/kumi golden_v2 diff --repr df <schema>       # unified diff
bundle exec bin/kumi golden_v2 update --repr vec,loop        # regenerate layers
```

Groups: `frontend`, `df`, `vec`, `loop`, `codegen`, `all`.

## Runtime Ground Truth

```bash
bundle exec bin/kumi golden test            # regenerate + execute Ruby and JS
bundle exec bin/kumi golden test <schema>
```

## Search Goldens Instead of Reading Them

Some golden artifacts are large (`game_of_life`, `us_tax_2024`) — grep them:

```bash
rg -n "reduce" golden -g"dfir*.txt"
rg -n "axis_shift" golden -g"vecir.txt"
rg -n "function" golden/<schema>/expected/loopir.txt
```

## Other Useful Commands

```bash
bundle exec bin/kumi analyze <schema> --dump <state_key>   # inspect analyzer state
bundle exec rspec                                          # full test suite
```

`tmp/` is gitignored and a good place for debug scripts.
