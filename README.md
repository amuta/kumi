# Kumi

[![CI](https://github.com/amuta/kumi/workflows/CI/badge.svg)](https://github.com/amuta/kumi/actions)
[![Gem Version](https://badge.fury.io/rb/kumi.svg)](https://badge.fury.io/rb/kumi)

**[Try the interactive demo →](https://kumi-play-web.fly.dev/)**

---

**Status**: experimental. Public API may change. Typing and some static checks are still evolving.

**Feedback**: have a use case or a paper cut? Open an issue or reach out.

---


**Declarative calculation DSL for Ruby.** Write business rules once, run them anywhere.

Kumi compiles high-level schemas into standalone Ruby and JavaScript with no runtime dependencies.

**Built for:** finance, tax, pricing, insurance, payroll, analytics—domains where correctness and transparency matter.

---

## Example: Conway's Game of Life


<details>
<summary><strong>Schema</strong></summary>

```ruby
module GameOfLife
  extend Kumi::Schema

  schema do
    input do
      array :rows do
        array :col do
          integer :alive # 0 or 1
        end
      end
    end

    let :a, input.rows.col.alive

    # axis_offset: 0 = x, 1 = y
    let :n,  shift(a, -1, axis_offset: 1)
    let :s,  shift(a,  1, axis_offset: 1)
    let :w,  shift(a, -1)
    let :e,  shift(a,  1)
    let :nw, shift(n, -1)
    let :ne, shift(n,  1)
    let :sw, shift(s, -1)
    let :se, shift(s,  1)

    let :neighbors, fn(:sum, [n, s, w, e, nw, ne, sw, se])

    # Conway rules
    let :alive, a > 0
    let :n3_alive, neighbors == 3
    let :n2_alive, neighbors == 2
    let :keep_alive, n2_alive & alive

    let :next_alive, n3_alive | keep_alive

    value :next_state, select(next_alive, 1, 0)
  end

end
````

</details>


<details>
<summary><strong>Generated JavaScript (excerpt)</strong></summary>

```js
export function _next_state(input) {
  let out = [];
  let t285 = input["rows"];
  let t1539 = t285.length;
  const t1540 = -1;
  const t1542 = 0;
  const t1546 = 1;
  const t1334 = 3;
  const t1339 = 2;
  let t1547 = t1539 - t1546;
  t285.forEach((rows_el_286, rows_i_287) => {
    let out_1 = [];
    let t1541 = rows_i_287 - t1540;
    let t1561 = rows_i_287 - t1546;
    let t1580 = ((rows_i_287 % t1539) + t1539) % t1539;
    // ... neighbor calculations, Conway's rules
    let t1332 = [t1557, t1577, t1597, t1617, t1645, t1673, t1701, t1729];
    let t1333 = t1332.reduce((a, b) => a + b, 0);
    let t1335 = t1333 == t1334;
    let t1340 = t1333 == t1339;
    let t1344 = col_el_288 > t1542;
    let t1345 = t1340 && t1344;
    let t528 = t1335 || t1345;
    let t293 = t528 ? t1546 : t1542;
    out_1.push(t293);
  });
  return out;
}
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
  config.compilation_mode = :jit
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

# Export to JavaScript
Double.write_source("output.mjs", platform: :javascript)
```

---

## License

MIT License. See [LICENSE](LICENSE).
