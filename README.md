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

**Feedback**: have a use case or hit a rough edge? Open an issue or reach out.

---

## Example: US Tax Calculator (2024)

A single schema computes federal, state, FICA taxes across multiple filing statuses. See the [interactive demo](https://kumi-play-web.fly.dev/) or inspect the [full schema, input, output, and generated code](golden/us_tax_2024/).

<details>
<summary><strong>Schema</strong></summary>

```ruby
schema do
  input do
    float  :income
    float  :state_rate
    float  :local_rate
    float  :retirement_contrib
    string :filing_status

    array :statuses do
      hash :status do
        string :name
        float  :std
        float  :addl_threshold
        array  :rates do
          hash :bracket do
            float :lo
            float :hi # -1 = open-ended
            float :rate
          end
        end
      end
    end
  end

  # shared
  let :big_hi, 100_000_000_000.0
  let :state_tax, input.income * input.state_rate
  let :local_tax, input.income * input.local_rate

  # FICA constants
  let :ss_wage_base, 168_600.0
  let :ss_rate, 0.062
  let :med_base_rate, 0.0145
  let :addl_med_rate, 0.009

  # per-status federal
  let :taxable,   fn(:max, [input.income - input.statuses.status.std, 0])
  let :lo,        input.statuses.status.rates.bracket.lo
  let :hi,        input.statuses.status.rates.bracket.hi
  let :rate,      input.statuses.status.rates.bracket.rate
  let :hi_eff,    select(hi == -1, big_hi, hi)
  let :amt,       fn(:clamp, taxable - lo, 0, hi_eff - lo)
  let :fed_tax,   fn(:sum, amt * rate)
  let :in_br,     (taxable >= lo) & (taxable < hi_eff)
  let :fed_marg,  fn(:sum_if, rate, in_br)
  let :fed_eff,   fed_tax / fn(:max, [input.income, 1.0])

  # per-status FICA
  let :ss_tax,         fn(:min, [input.income, ss_wage_base]) * ss_rate
  let :med_tax,        input.income * med_base_rate
  let :addl_med_tax,   fn(:max, [input.income - input.statuses.status.addl_threshold, 0]) * addl_med_rate
  let :fica_tax,       ss_tax + med_tax + addl_med_tax
  let :fica_eff,       fica_tax / fn(:max, [input.income, 1.0])

  # totals per status
  let :total_tax,  fed_tax + fica_tax + state_tax + local_tax
  let :total_eff,  total_tax / fn(:max, [input.income, 1.0])
  let :after_tax,  input.income - total_tax
  let :take_home,  after_tax - input.retirement_contrib

  # array of result objects, one per status
  value :summary, {
    filing_status: input.statuses.status.name,
    federal: { marginal: fed_marg, effective: fed_eff, tax: fed_tax },
    fica: { effective: fica_eff, tax: fica_tax },
    state: { marginal: input.state_rate, effective: input.state_rate, tax: state_tax },
    local: { marginal: input.local_rate, effective: input.local_rate, tax: local_tax },
    total: { effective: total_eff, tax: total_tax },
    after_tax: after_tax,
    retirement_contrib: input.retirement_contrib,
    take_home: take_home
  }
end
```

</details>

---

## Install

```bash
gem install kumi
```

Requires Ruby 3.1+. No external dependencies.

## Quick Start

```ruby
require 'kumi'

Kumi.configure do |config|
  # Optional override; defaults to ENV["KUMI_COMPILATION_MODE"] or :jit in development/:aot otherwise
  config.compilation_mode = :jit
  config.cache_path = File.expand_path("tmp/kumi_cache", __dir__)
end

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
```

You can also override the compilation strategy without touching code by setting
`KUMI_COMPILATION_MODE` to `jit` or `aot` (e.g. `export KUMI_COMPILATION_MODE=jit`).

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
