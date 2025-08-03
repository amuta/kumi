# JavaScript Transpiler

Transpiles compiled schemas to standalone JavaScript code.

## Usage

### Export Schema

```ruby
class TaxCalculator
  extend Kumi::Schema
  
  schema do
    input do
      float :income
      string :filing_status
    end
    
    trait :single, input.filing_status == "single"
    
    value :std_deduction do
      on single, 14_600
      base 29_200
    end
    
    value :taxable_income, fn(:max, [input.income - std_deduction, 0])
    value :tax_owed, taxable_income * 0.22
  end
end

Kumi::Js.export_to_file(TaxCalculator, "tax-calculator.js")
```

### Use in JavaScript

```javascript
const { schema } = require('./tax-calculator.js');

const taxpayer = {
  income: 75000,
  filing_status: "single"
};

const calculator = schema.from(taxpayer);
console.log(calculator.fetch('tax_owed'));

const results = calculator.slice('taxable_income', 'tax_owed');
```

## Export Methods

### Command Line

```bash
bundle exec kumi --export-js output.js SchemaClass
```

### Programmatic

```ruby
Kumi::Js.export_to_file(MySchema, "schema.js")

js_code = Kumi::Js.compile(MySchema)
File.write("output.js", js_code)
```

## JavaScript API

### schema.from(input)

Creates runner instance.

```javascript
const runner = schema.from({ income: 50000, status: "single" });
```

### runner.fetch(key)

Returns computed value. Results are cached.

```javascript
const tax = runner.fetch('tax_owed');
```

### runner.slice(...keys)

Returns multiple values.

```javascript
const results = runner.slice('taxable_income', 'tax_owed');
// Returns: { taxable_income: 35400, tax_owed: 7788 }
```

### runner.functionsUsed

Array of functions used by the schema.

```javascript
console.log(runner.functionsUsed); // ["max", "subtract", "multiply"]
```

## Function Optimization

The transpiler only includes functions actually used by the schema.

Example schema using 4 functions generates ~3 KB instead of ~8 KB with all 67 functions.

## Browser Compatibility

- ES6+ (Chrome 60+, Firefox 55+, Safari 10+) 
- Modern bundlers (Webpack, Rollup, Vite)
- Node.js 12+

## Limitations

- No `explain()` method (Ruby only)
- Custom Ruby functions need JavaScript equivalents

## Module Formats

Generated JavaScript supports:
- CommonJS (`require()`)
- ES Modules (`import`) 
- Global variables (browser)

## Minification

Use production minifiers like Terser or UglifyJS for smaller bundles.

## Dual Mode Validation

Set `KUMI_DUAL_MODE=true` to automatically execute both Ruby and JavaScript versions and validate they produce identical results:

```bash
KUMI_DUAL_MODE=true ruby my_script.rb
```

Every calculation is validated in real-time. Mismatches throw detailed error reports with both results for debugging.

## Error Handling

```javascript
try {
  const runner = schema.from({ invalid: "data" });
} catch (error) {
  console.error(error.message);
}
```