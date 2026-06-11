# Kumi

[![CI](https://github.com/amuta/kumi/workflows/CI/badge.svg)](https://github.com/amuta/kumi/actions)
[![Gem Version](https://badge.fury.io/rb/kumi.svg)](https://badge.fury.io/rb/kumi)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[Try the interactive demo →](https://kumi-play-web.fly.dev/)**

---

## What is Kumi?

Kumi is a **declarative DSL for calculation logic** — tax rules, pricing, scoring, financial projections — that compiles to plain Ruby and JavaScript.

You declare the shape of your input data and the values you want computed. The compiler determines evaluation order, checks types, detects impossible conditions, and emits dependency-free code for each target.

```ruby
schema do
  input do
    array :items do
      hash :item do
        integer :quantity
        decimal :unit_price
      end
    end
  end

  value :line_totals, input.items.item.quantity * input.items.item.unit_price
  value :subtotal, fn(:sum, line_totals)
end
```

No loops, no iteration plumbing: `line_totals` is computed per item because that's where the data lives, and `fn(:sum, ...)` collapses it back to a scalar. This works through arbitrarily nested arrays.

## Why

- **One source of truth, two targets.** The same schema compiles to Ruby and JavaScript with identical semantics — write pricing logic once, run it in your backend and in the browser preview.
- **Broadcasting from data shape.** Operations align over arrays automatically based on the declared input structure, including nested and ragged data.
- **Static checks at compile time.** Type checking, dependency cycle detection, and unsatisfiable-constraint detection happen when the schema is defined, not in production.
- **Boring generated code.** Output is deterministic, dependency-free, straight-line code with explicit loops. What you read is what runs.

## Use Cases

Tax engines, pricing models, financial projections, compliance rules, insurance underwriting, shipping rate calculators — anywhere calculation logic must be correct, auditable, and consistent across platforms.

---

**Status**: experimental. Public API may change. Typing and some static checks are still evolving.

**Feedback**: have a use case or hit a rough edge? Open an issue or reach out (andremuta+kumi@gmail.com).

---

## Install

```bash
gem install kumi
```

Requires Ruby 3.1+. Runtime dependencies: `mutex_m` and `zeitwerk` (bundled via Rubygems).

## Quick Start

```ruby
require 'kumi'

module Double
  extend Kumi::Schema

  schema do
    input { integer :x }
    value :doubled, input.x * 2
  end
end

# Execute in Ruby
result = Double.from(x: 5)
result[:doubled]  # => 10

# or just call the method directly
Double._doubled(x: 5) # => 10

# Export to JavaScript (same logic)
Double.write_source("output.mjs", platform: :javascript)
# ./output.mjs
# export function _doubled(input) {
#   let t1 = input["x"];
#   let t3 = t1 * 2;
#   return t3;
# }
```

You can also override the compilation strategy without touching code by setting
`KUMI_COMPILATION_MODE` to `jit` or `aot` (e.g. `export KUMI_COMPILATION_MODE=aot`).

## Examples

- **US Tax Calculator (2024)** — a single schema computes federal, state, and FICA taxes across multiple filing statuses. [Open in the demo](https://kumi-play-web.fly.dev/?example=us-federal-tax-2024).
- **Monte Carlo Portfolio** — probabilistic simulations and table visualizations. [Open in the demo](https://kumi-play-web.fly.dev/?example=monte-carlo-simulation).
- **Conway's Game of Life** — array operations powering a grid-based simulation. [Open in the demo](https://kumi-play-web.fly.dev/?example=game-of-life).

---

## Documentation

- **[Syntax Reference](docs/SYNTAX.md)** — DSL syntax, types, operators, functions
- **[Functions Reference](docs/FUNCTIONS.md)** — auto-generated docs for all functions and kernels ([machine-readable JSON](docs/functions-reference.json))
- **[Schema Imports](docs/SCHEMA_IMPORTS.md)** — composing and reusing schemas
- **[Architecture](docs/ARCHITECTURE.md)** — the compiler pipeline and IR stack
- **[Golden Tests](docs/GOLDEN_TESTS.md)** — the end-to-end test harness
- **[Development Guide](docs/DEVELOPMENT.md)** — tooling, docs generation, IDE integration

---

## License

MIT License. See [LICENSE](LICENSE).
