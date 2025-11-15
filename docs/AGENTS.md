# Agent Reference

Helpful commands for inspecting and debugging Kumi IRs.

## DFIR Investigation

- **Regenerate goldens for a schema (all IR dumps + outputs):**
  ```bash
  bundle exec bin/kumi golden update <schema>
  # e.g.
  bundle exec bin/kumi golden update multi_loop_reduction
  ```

- **Inspect a schema’s DFIR dump:**
  ```bash
  sed -n '1,160p' golden/<schema>/expected/dfir.txt
  rg -n "function" golden/<schema>/expected/dfir.txt
  ```

- **Search across all goldens for patterns (nested loops, axes, etc.):**
  ```bash
  rg -n "reduce" golden -g"dfir*.txt"
  rg -n "axis_shift" golden -g"dfir*.txt"
  ```

Use the snippets above as a toolbox when iterating on IR passes or reviewing
golden diffs.
