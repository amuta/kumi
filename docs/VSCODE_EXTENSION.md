# VSCode Extension for Kumi

The `vscode-extension/` directory contains a VSCode extension that provides IDE support for Kumi functions using the auto-generated function reference.

## What It Does

- **Autocomplete** - Suggest function names when typing `fn(:`
- **Hover Documentation** - Show function signatures, parameters, and types
- **Type Information** - Display type inference rules for each function
- **Arity Display** - Show parameter counts at a glance

## Setup

### 1. Build the Extension

```bash
cd vscode-extension
npm install
npm run compile
```

This generates JavaScript in `out/extension.js` from the TypeScript sources.

### 2. Install in VSCode

**Option A: Load as Development Extension**

- Open the `vscode-extension` folder in VSCode
- Press `F5` to launch a debugging session
- The extension will activate automatically

**Option B: Package as VSIX**

```bash
npm install -g vsce
vsce package
```

Then install the generated `.vsix` file in VSCode via "Extensions: Install from VSIX"

### 3. Generate Function Data

Before using the extension, ensure the function reference JSON is up-to-date:

```bash
bin/kumi-doc-gen
```

This creates `docs/functions-reference.json` which the extension reads.

## Usage in VSCode

When editing Ruby files in a Kumi project:

```ruby
# Start typing fn(: to get suggestions
fn(:add, x, y)     # ← Autocomplete shows available functions
   ↑
   # Hover to see: core.add (arity: 2, type: promoted from left_operand, right_operand)

# Completions include:
# - add, sub, mul, div, pow (arithmetic)
# - sum, count, min, max, mean (aggregations)
# - ... and all other functions
```

The extension provides:
- Full function name with backticks for easy identification
- Arity (parameter count)
- Type inference rules
- Parameter names
- Available kernel implementations

## Data Flow

```
data/functions/ (YAML)
      ↓
bin/kumi-doc-gen
      ↓
docs/functions-reference.json
      ↓
vscode-extension/src/extension.ts
      ↓
VSCode IDE features (autocomplete, hover, etc.)
```

## Development

To modify the extension:

1. Edit `vscode-extension/src/extension.ts`
2. Run `npm run watch` to auto-compile TypeScript
3. Press `F5` in VSCode to reload the debugging session
4. Test new features against the live extension

## Limitations

Currently the extension:
- Only provides autocomplete after `fn(:`
- Only works with Ruby files
- Doesn't validate argument types at compile time
- Doesn't provide inline hints during parameter entry

These could be added as future enhancements!

## Future Enhancements

- Parameter validation (type checking)
- Signature help (inline parameter hints)
- Go-to-definition for function implementations
- Diagnostics for arity mismatches
- Snippet expansion for common patterns
- LSP server for language-agnostic support
