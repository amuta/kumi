# Kumi Development Backlog

## High Priority

### RegistryV2 Migration Cleanup
- [ ] Remove legacy `lib/kumi/core/function_registry.rb` and related modules after RegistryV2 is fully integrated
- [ ] Clean up bridge code in `FunctionSignaturePass` once all functions are migrated
- [ ] Remove `create_basic_signature` fallback logic
- [ ] Update all tests to use RegistryV2 functions

## Medium Priority

### Function Registry Enhancements
- [ ] Add YAML linting for function definitions
- [ ] Implement golden-IR test fixtures for signature resolution
- [ ] Add Arrow/JS kernel mapping support
- [ ] Implement type promotion rules from YAML dtypes

### Performance Optimizations
- [ ] Cache RegistryV2 loading for repeated schema compilations
- [ ] Optimize signature resolution for large function sets
- [ ] Implement lazy loading of function kernels

## Low Priority

### Documentation
- [ ] Auto-generate function reference docs from YAML
- [ ] Add examples for each function in registry
- [ ] Document kernel implementation guidelines

### Testing
- [ ] Add comprehensive NEP-20 compliance test suite
- [ ] Stress test RegistryV2 with large function sets
- [ ] Add performance benchmarks for signature resolution