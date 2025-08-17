# Kumi Development Backlog

## High Priority

### Lazy Evaluation Completion
- [ ] Replace cascade `Map(mask.where)` operations with `Select` operations for consistency
- [ ] Add comprehensive specs for `Select` operation and lazy evaluation system
- [ ] Performance testing: verify right operands are not evaluated in short-circuit cases

### Hash Objects Implementation  
- [ ] Complete hash object access plan lowering (in progress)
- [ ] Add hash object broadcasting support for mixed array/hash operations
- [ ] Hash object integration with trait system

### User-Defined Function Support
- [ ] Design RegistryV2 API for runtime function registration
- [ ] Implement dynamic function definition system (YAML templates or programmatic API)
- [ ] Bridge RegistryV2 with legacy Registry for backward compatibility during transition
- [ ] Re-enable `spec/integration/arg_order_spec.rb` once user functions are supported
- [ ] Documentation and examples for custom function registration

### RegistryV2 Migration Cleanup
- [ ] Remove legacy `lib/kumi/core/function_registry.rb` and related modules after RegistryV2 is fully integrated
- [ ] Clean up bridge code in `FunctionSignaturePass` once all functions are migrated  
- [ ] Remove `create_basic_signature` fallback logic
- [ ] Update all tests to use RegistryV2 functions
- [ ] Add WARN_DEPRECATED_FUNCS as default?

### SchemaMetadata Removal Cleanup
- [x] ~~Remove `SchemaMetadata` class and related files~~ (Completed)
- [x] ~~Remove `JsonSchema` module and related files~~ (Completed - was tightly coupled to SchemaMetadata)
- [ ] Consider alternative tooling API for schema introspection (if needed)
- [ ] Update any external docs/examples that referenced `schema_metadata` method
- [ ] Reimplement JSON Schema generation working directly with analyzer state (if needed)

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