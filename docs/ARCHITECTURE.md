# Kumi Documentation & IDE Architecture

## Overview

This document describes the automatic documentation generation system and IDE support infrastructure for Kumi functions and kernels.

## System Architecture

```
┌─────────────────────────────────────┐
│  Function & Kernel Definitions      │
├─────────────────────────────────────┤
│  data/functions/*.yaml              │
│  data/kernels/**/*.yaml             │
└──────────────┬──────────────────────┘
               │
        ┌──────▼──────┐
        │ bin/kumi-   │
        │ doc-gen     │
        └──────┬──────┘
               │
      ┌────────┴────────┐
      │                 │
   ┌──▼───┐      ┌─────▼──────┐
   │ JSON │      │  Markdown  │
   │ Data │      │  Reference │
   └──┬───┘      └─────┬──────┘
      │                │
  ┌───▼──────────┐ ┌───▼─────────────────┐
  │ IDE Tools    │ │ Developers/Docs     │
  ├──────────────┤ ├─────────────────────┤
  │ VSCode       │ │ docs/FUNCTIONS.md   │
  │ Monaco       │ │ GitHub Reference    │
  │ LSP Servers  │ │ API Documentation   │
  └──────────────┘ └─────────────────────┘
```

## Core Components

### 1. Data Sources

**Function Definitions** (`data/functions/*.yaml`)
```yaml
functions:
  - id: agg.sum
    kind: reduce
    params: [{ name: source_value }]
    dtype: { rule: same_as, param: source_value }
    reduction_strategy: identity  # KEY: Identity-based reducer
    aliases: ["sum"]

  - id: agg.min
    kind: reduce
    params: [{ name: source_value }]
    dtype: { rule: element_of, param: source_value }
    reduction_strategy: first_element  # KEY: First-element reducer
    aliases: ["min"]
```

**Kernel Implementations** (`data/kernels/ruby/*.yaml`)
```yaml
kernels:
  - id: agg.sum:ruby:v1
    fn: agg.sum
    inline: "+= $1"
    impl: "(a,b)\n  a + b"
    fold_inline: "= $0.sum"
    identity:
      float: 0.0
      integer: 0
```

### 2. Doc Generator Module

**Location:** `lib/kumi/doc_generator/`

#### Loader
- Parses YAML files from `data/functions/` and `data/kernels/`
- Returns raw function and kernel definitions
- No transformation or filtering

#### Merger
- Combines function definitions with kernel implementations
- Creates entries indexed by function aliases (so `sum`, `add`, `sub` all resolvable)
- Extracts important metadata:
  - `reduction_strategy` - How the reducer initializes
  - `dtype` - Type inference rules
  - `arity` - Parameter count
  - `kernels` - Available implementations

#### Formatters

**Json Formatter**
- Output: `docs/functions-reference.json`
- Consumer: IDE plugins (VSCode, Monaco, etc.)
- Data:
  - Function ID and aliases
  - Arity and parameter info
  - Type information
  - Kernel availability
  - **Reduction strategy** (for reducer distinction)

**Markdown Formatter**
- Output: `docs/FUNCTIONS.md`
- Consumer: Developers, documentation sites
- Presentation:
  - Human-readable function descriptions
  - Inline operations (`$0 = accumulator, $1 = element`)
  - Actual implementation code
  - Fold strategies
  - Identity values (when applicable)
  - **Reduction semantics** (monoid vs first-element)

### 3. VSCode Extension

**Location:** `vscode-extension/`

**Features:**
- Autocomplete for functions when typing `fn(:`
- Hover tooltips with signatures
- Schema block context detection (Ruby files only)
- Works with `.kumi` and `.rb` files

**Components:**
- `FunctionCompletionProvider` - Offers suggestions
- `FunctionHoverProvider` - Shows detailed information
- `isInSchemaBlock()` - Detects if inside `schema do...end` block (Ruby files)

## Key Design Decisions

### 1. Reduction Strategy Distinction

**Problem:** Min/Max don't have identity values like Sum/Count do.

**Solution:** Capture `reduction_strategy` from YAML:
- `identity` → Monoid operation, can use identity element
- `first_element` → First array element initializes accumulator

**Display:**
- Markdown shows: "Monoid operation with identity element" or "First element is initial value"
- JSON includes: `"reduction_strategy": "identity" | "first_element"`

### 2. Kernel Implementation Visibility

**Decision:** Show actual kernel code inline in markdown.

**Benefits:**
- Developers see what the function actually does
- Inline operations (`+= $1` vs `= $1 if $1 < $0`) show the pattern
- Implementation code is actual Ruby/JavaScript

**Format:**
```markdown
**Inline:** `+= $1` ($0 = accumulator, $1 = element)
**Implementation:**
```ruby
(a,b)
  a + b
```
**Fold:** `= $0.sum`
**Identity:** float: 0.0, integer: 0
```

### 3. Single Source of Truth

**Flow:**
```
YAML definitions
    ↓
bin/kumi-doc-gen (one command)
    ↓
    ├→ docs/FUNCTIONS.md (auto-generated)
    ├→ docs/functions-reference.json (auto-generated)
    └→ IDE/Tools consume JSON
```

Changes to function definitions automatically flow to:
- IDE completions
- Markdown reference
- JSON API

### 4. Context-Aware IDE Support

**Ruby files:** Only offer completions inside `schema do...end` blocks
- Prevents noise from unrelated `fn(:` calls
- Tracks brace nesting to detect context

**Kumi files:** Always available
- Native language file type

## Data Model

### Function Entry (After Merge)
```json
{
  "id": "agg.sum",
  "kind": "reduce",
  "arity": 1,
  "params": [{ "name": "source_value" }],
  "dtype": { "rule": "same_as", "param": "source_value" },
  "aliases": ["sum"],
  "reduction_strategy": "identity",
  "kernels": {
    "ruby": {
      "id": "agg.sum:ruby:v1",
      "inline": "+= $1",
      "impl": "(a,b)\n  a + b",
      "fold_inline": "= $0.sum",
      "identity": { "float": 0.0, "integer": 0 }
    }
  }
}
```

## Usage Workflows

### For End Users

**View function reference:**
```bash
# Markdown documentation
open docs/FUNCTIONS.md

# IDE support (VSCode)
cd vscode-extension && npm install && npm run compile
# Press F5 in VSCode
```

### For Developers

**Modify functions:**
1. Update `data/functions/category/*.yaml`
2. Run `bin/kumi-doc-gen`
3. Commit both YAML and generated files

**Add new reducer:**
```yaml
- id: agg.product
  kind: reduce
  params: [{ name: source_value }]
  reduction_strategy: identity
  aliases: ["product"]
```
Add kernel in `data/kernels/ruby/agg/numeric.yaml`, then regenerate docs.

## Extension Points

The architecture supports adding:

1. **New formatters** (HTML, PDF, LSP protocol)
2. **New generators** (TypeScript definitions, GraphQL schema)
3. **New IDE support** (Neovim, Emacs plugins via LSP)
4. **Validation** (against declared types/arity)

All through the same YAML source data.

## Testing

- 8 comprehensive tests for doc generation
- All 944 existing Kumi tests pass
- No regression in core functionality

## Performance

- **Generation time:** <100ms for all functions
- **File sizes:**
  - FUNCTIONS.md: ~950 lines
  - functions-reference.json: ~1800 lines
- **IDE load time:** Instant (JSON loaded once on activation)

## Future Improvements

1. **LSP Server**: Standalone language server for any editor
2. **Type validation**: Check function call arity at compile time
3. **IDE diagnostics**: Show type mismatches as you type
4. **Documentation linking**: Cross-reference related functions
5. **Kernel visualization**: Show kernel implementations side-by-side
