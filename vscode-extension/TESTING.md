# Testing the Kumi VSCode Extension

## Quick Start

### 1. Build the Extension

```bash
cd vscode-extension
npm install
npm run compile
```

### 2. Generate Function Data

Before testing, generate the function reference JSON:

```bash
# From kumi root
bin/kumi-doc-gen
```

This creates `docs/functions-reference.json` that the extension reads.

### 3. Launch Extension in Debug Mode

```bash
# From vscode-extension directory
code ..
```

Or just open the kumi repo root in VSCode, then:
- Press `F5` to start debugging
- A new VSCode window will open with the extension loaded

### 4. Test Autocomplete and Hover

Open `examples/demo-extension.kumi` in the debug window.

Position cursor after `fn(:` and type to trigger autocomplete:

```kumi
# Example 1: Basic arithmetic
let :sum, fn(:add, x, y)
                 ↑
                 Type here and wait for suggestions
```

**Expected behavior:**
- Autocomplete shows `add`, `sub`, `mul`, `div`, etc.
- Each suggestion shows arity and function ID
- Press Escape to close, or select with Enter

### 5. Test Hover Information

Hover over function names to see documentation:

```kumi
let :sum, fn(:sum, input.values.item.price)
               ↑
               Hover here to see type info
```

**Expected behavior:**
- Popup shows:
  - Function name: `agg.sum`
  - Arity: `1`
  - Type: `same as source_value`
  - Parameters: `source_value`
  - Kernels: `ruby: agg.sum:ruby:v1`

### 6. Test Different Function Types

Try these in the demo file:

**Functions with identity:**
```kumi
fn(:sum, ...)    # Shows Inline: += $1
fn(:count, ...)  # Shows Inline: += 1
fn(:any, ...)    # Shows Inline: = $0 || $1
```

**Functions without identity:**
```kumi
fn(:min, ...)    # No Inline, shows note about first element
fn(:max, ...)    # No Inline, shows note about first element
```

**Functions with multiple aliases:**
```kumi
fn(:add, ...)       # Has alias: add
fn(:mul, ...)       # Has aliases: mul, multiply
fn(:sum_if, ...)    # Complex aggregation
```

### 7. Watch for Recompilation

In the debug window, TypeScript changes auto-compile:

```bash
npm run watch
```

Make a change to `src/extension.ts`, save, and reload the debug window (Cmd+R / Ctrl+R) to see changes.

## Troubleshooting

### Extension doesn't load

Check the Debug Console for errors:
- `Cmd+Shift+J` (Mac) or `Ctrl+Shift+J` (Linux/Windows)

### No autocomplete suggestions

1. Verify `docs/functions-reference.json` exists
2. Check extension loaded: Look for "Kumi functions reference loaded" in Debug Console
3. Make sure cursor is after `fn(:`

### JSON loading errors

If you see "Could not find functions-reference.json":
```bash
# Regenerate the JSON
bin/kumi-doc-gen
```

### Type suggestions not showing

1. Ensure you're in a `.kumi` or `.rb` file
2. Check the file language is recognized (bottom-right of editor shows language)
3. Try clicking on a function name and pressing `Cmd+K Cmd+I` to force hover

## File Locations

- Extension code: `vscode-extension/src/extension.ts`
- Function data: `docs/functions-reference.json`
- Demo file: `examples/demo-extension.kumi`
- VSCode config: `vscode-extension/package.json`

## Testing on Different File Types

### Kumi Files (.kumi)
```kumi
fn(:add, x, y)    # Autocomplete and hover work
```

### Ruby Files (.rb)
```ruby
fn(:add, x, y)    # Also works if inside Kumi schema
```

Both file types activate the extension and provide completions/hover.
