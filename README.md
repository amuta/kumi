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

## Composing Schemas

Schemas can import other schemas — and the compiler **inlines everything at compile time**. The generated code has no runtime dependency on the imported module; imported logic participates in broadcasting and loop fusion like any locally written expression.

```ruby
module TaxPolicy
  extend Kumi::Schema

  schema do
    input { decimal :amount }
    value :tax, input.amount * 0.15
  end
end

module Order
  extend Kumi::Schema

  schema do
    import :tax, from: TaxPolicy

    input do
      array :items do
        hash :item do
          decimal :price
        end
      end
    end

    # TaxPolicy only knows a scalar :amount — passing a vectorized
    # argument applies it per item automatically.
    value :item_taxes, fn(:tax, amount: input.items.item.price)
    value :total_tax, fn(:sum, item_taxes)
  end
end

Order.from(items: [{ price: 100 }, { price: 200 }, { price: 300 }])[:total_tax]
# => 90.0
```

The generated JavaScript for `total_tax` shows what "inline everything" means — the imported tax rule **and** the `sum` reduction are fused into one loop, with no call to `TaxPolicy`, no intermediate array, and no runtime to ship:

```js
export function _total_tax(input) {
  let t13 = input["items"];
  let acc18 = 0.0;
  for (let items_i15 = 0; items_i15 < t13.length; items_i15++) {
    let items_el14 = t13[items_i15];
    let t16 = items_el14["price"];
    let t17 = 0.15;
    let t12 = t16 * t17;
    acc18 += t12;
  }
  let t6 = acc18;
  return t6;
}
```

See [Schema Imports](docs/SCHEMA_IMPORTS.md) for renamed inputs, multiple imports, and imports over nested arrays.

## Performance

Compiled schemas are straight-line code with fused loops — there is no interpreter, rule engine, or library call in the artifact, so the runtime cost is whatever the host language charges for a `for` loop.

Two playground examples make this tangible:

- **[Payroll at Scale](https://kumi-play-web.fly.dev/?example=payroll-at-scale)** — a full payroll run (overtime split, progressive withholding bands, ten aggregates) over **10,000 employees in ~0.2 ms per call** in desktop Chrome. Press **Benchmark ×100** in the Execute tab to measure median / p95 on your own machine.
- **[Game of Life XL](https://kumi-play-web.fly.dev/?example=life-xl)** — Conway's rules over an **83,000-cell grid**, stepping live in a worker with the nine neighbor reads fused into a single pass — millions of cell updates per second, rendered in real time with a live counter.

## Examples

- **US Tax Calculator (2024)** — a single schema computes federal, state, and FICA taxes across multiple filing statuses. [Open in the demo](https://kumi-play-web.fly.dev/?example=us-federal-tax-2024).
- **Payroll at Scale** — overtime, withholding bands, and aggregates over 10,000 employees with per-run timing. [Open in the demo](https://kumi-play-web.fly.dev/?example=payroll-at-scale).
- **Monte Carlo Portfolio** — probabilistic simulations and table visualizations. [Open in the demo](https://kumi-play-web.fly.dev/?example=monte-carlo-simulation).
- **Conway's Game of Life** — array operations powering a grid-based simulation ([XL version](https://kumi-play-web.fly.dev/?example=life-xl) runs 83k cells live). [Open in the demo](https://kumi-play-web.fly.dev/?example=game-of-life).

The playground's example picker groups these by theme (language tour, business logic, scale & speed, simulations) — the [Language Intro](https://kumi-play-web.fly.dev/?example=language-intro) is the best starting point.

---

## Documentation

- **[Syntax Reference](docs/SYNTAX.md)** — DSL syntax, types, operators, functions
- **[Syntax Notes](docs/SYNTAX_NOTES.md)** — parser differences, nested input recipes, expression literals, and post-parse errors
- **[Input Shapes](docs/INPUTS.md)** — declaring scalars, arrays, hashes, and the element rule
- **[Functions Reference](docs/FUNCTIONS.md)** — auto-generated docs for all functions and kernels ([machine-readable JSON](docs/functions-reference.json))
- **[Cross-Target Semantics](docs/CROSS_TARGET_SEMANTICS.md)** — where Ruby and JS would diverge (float `to_string`, string conversions, `pow`) and how the kernels keep them identical
- **[Schema Imports](docs/SCHEMA_IMPORTS.md)** — composing and reusing schemas
- **[Architecture](docs/ARCHITECTURE.md)** — the compiler pipeline and IR stack
- **[Golden Tests](docs/GOLDEN_TESTS.md)** — the end-to-end test harness
- **[Development Guide](docs/DEVELOPMENT.md)** — tooling, docs generation, IDE integration

---

## License

MIT License. See [LICENSE](LICENSE).
