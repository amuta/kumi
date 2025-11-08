# Kumi

[![CI](https://github.com/amuta/kumi/workflows/CI/badge.svg)](https://github.com/amuta/kumi/actions)
[![Gem Version](https://badge.fury.io/rb/kumi.svg)](https://badge.fury.io/rb/kumi)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[Try the interactive demo →](https://kumi-play-web.fly.dev/)**

---

## What is Kumi?

Kumi is a **declarative DSL for building calculation systems**.

Schemas define:
- Input shape (scalars, arrays, nested structures)
- Declarations (computed values and boolean conditions)
- Dependencies between declarations

The compiler:
- Performs type checking
- Detects unsatisfiable constraints
- Determines evaluation order
- Generates code for Ruby or JavaScript

## Use Cases

Calculation systems appear in: tax engines, pricing models, financial projections, compliance systems, insurance underwriting, shipping rate calculators.

---

**Status**: experimental. Public API may change. Typing and some static checks are still evolving.

**Feedback**: have a use case or hit a rough edge? Open an issue or reach out (andremuta+kumi@gmail.com).

---

## Examples

- **US Tax Calculator (2024)** — a single schema computes federal, state, and FICA taxes across multiple filing statuses. [Open in the demo](https://kumi-play-web.fly.dev/?example=us-federal-tax-2024).
- **Monte Carlo Portfolio** — demonstrates probabilistic simulations and table visualizations. [Open in the demo](https://kumi-play-web.fly.dev/?example=monte-carlo-simulation).
- **Conway's Game of Life** — showcases array operations powering a grid-based simulation. [Open in the demo](https://kumi-play-web.fly.dev/?example=game-of-life).

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

Try the [interactive demo](https://kumi-play-web.fly.dev/) (no setup required).

---

## Documentation

- **[Syntax Reference](docs/SYNTAX.md)** - DSL syntax, types, operators, functions, and schema imports
- **[Functions Reference](docs/FUNCTIONS.md)** - Auto-generated docs for all functions and kernels
- **[functions-reference.json](docs/functions-reference.json)** - Machine-readable format for IDEs (VSCode, Monaco, etc.)
- **[Development Guide](docs/DEVELOPMENT.md)** - Testing, debugging, and contributing

To regenerate function docs: `bin/kumi-doc-gen`

---

## License

MIT License. See [LICENSE](LICENSE).
