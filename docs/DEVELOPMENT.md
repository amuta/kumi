# Kumi Development Guide

This document covers common development tasks and tools.

## Documentation Generation

### Generating Function Reference

Kumi automatically generates documentation for functions and kernels from YAML definitions:

```bash
bin/kumi-doc-gen
```

This generates:
- **JSON:** `docs/functions-reference.json` - IDE-friendly format with function signatures, parameters, and kernel mappings
- **Markdown:** `docs/FUNCTIONS.md` - Human-readable function reference

The generated docs can be used by:
- IDEs (VSCode, Monaco) for autocomplete and hover information
- API documentation sites
- LSP servers for language features
- Custom tooling

Run this whenever you modify function definitions in `data/functions/` or kernels in `data/kernels/`.

### Module: `Kumi::DocGenerator`

Located in `lib/kumi/doc_generator/`, this module provides:

- **`Loader`** - Load function and kernel definitions from YAML
- **`Merger`** - Combine function metadata with kernel implementations
- **`Formatters::Json`** - Generate IDE-consumable JSON
- **`Formatters::Markdown`** - Generate markdown documentation

The module is decoupled from the analyzer and compilation pipeline, making it suitable for independent use.

## IDE Integration

### VSCode Extension

The `vscode-extension/` directory contains a VSCode extension that provides:
- Autocomplete for Kumi functions
- Hover tooltips with function signatures
- Type information and arity display

See [VSCODE_EXTENSION.md](VSCODE_EXTENSION.md) for setup and usage.

Quick start:
```bash
cd vscode-extension && npm install && npm run compile
# Then open in VSCode and press F5
```

The extension reads from `docs/functions-reference.json`, so always regenerate docs after function changes:
```bash
bin/kumi-doc-gen
```

---

*More development guides coming soon.*
