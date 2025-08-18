# frozen_string_literal: true

require 'set'

module Kumi
  # Public facade for the function registry.
  # Bridges old Registry interface to RegistryV2 for backward compatibility.
  module Registry
    def self.registry_v2
      @registry_v2 ||= create_composite_registry
    end

    def self.create_composite_registry
      # Create base registry from YAML
      base_registry = Core::Functions::RegistryV2.load_from_file
      
      # Create composite that checks custom functions first
      CompositeRegistry.new(base_registry, self)
    end

    def self.function?(name, arity: nil)
      registry_v2.function_exists?(name, arity: arity)
    end

    def self.supported?(name)
      registry_v2.function_exists?(name)
    end

    def self.fetch(name, opset: nil)
      # Return a callable that matches old interface
      registry_v2.get_executable_kernel(name)
    rescue KeyError => e
      raise "Function '#{name}' not found: #{e.message}"
    end

    def self.signature(name)
      # Return old-style signature hash for backward compatibility
      function = registry_v2.resolve(name)

      # Convert RegistryV2 function to old signature format
      {
        arity: function.signatures.first&.arity || -1,
        param_types: extract_param_types(function),
        return_type: extract_return_type(function),
        description: "#{function.name} (RegistryV2)"
      }
    rescue KeyError
      # Function not found
      {
        arity: -1,
        param_types: [],
        return_type: :any,
        description: "Unknown function"
      }
    end

    def self.all
      registry_v2.all_function_names.map(&:to_sym)
    end

    def self.functions
      # Return a hash that VM can use with registry[function_name]
      @functions_cache ||= begin
        functions_hash = {}
        registry_v2.all_function_names.each do |name|
          kernel = registry_v2.get_executable_kernel(name)
          functions_hash[name] = kernel
        end
        functions_hash
      end
    end

    # Legacy methods for specs that register custom functions
    def self.register_with_metadata(name, function, **metadata)
      # Skip registration - RegistryV2 doesn't support runtime registration yet
      # This is used in specs that are already marked as skipped
    end

    def self.register(name, &)
      # Skip registration - RegistryV2 doesn't support runtime registration yet
    end

    def self.reset!
      # Reset custom functions registry, but preserve protected functions
      protected_functions = (@protected_functions || []).to_set
      
      if protected_functions.any?
        # Keep only protected functions
        current_functions = @custom_functions || {}
        @custom_functions = current_functions.select { |name, _| protected_functions.include?(name) }
      else
        # Full reset if no protected functions
        @custom_functions = {}
      end
      
      @mutex = Mutex.new
      # Clear the composite registry cache so it picks up the reset
      @registry_v2 = nil
      # Clear the functions cache so it picks up changes
      @functions_cache = nil
    end

    # Protect functions from being cleared by reset!
    def self.protect_functions(*function_names)
      @protected_functions ||= Set.new
      @protected_functions.merge(function_names.map(&:to_s))
    end

    # Unprotect functions
    def self.unprotect_functions(*function_names)
      @protected_functions ||= Set.new
      @protected_functions.subtract(function_names.map(&:to_s))
    end

    # Clear all protected functions
    def self.clear_protection
      @protected_functions = Set.new
    end

    # ---- Function Builder API ----
    
    class BuildError < StandardError
      attr_reader :missing, :context
      def initialize(message, missing: [], context: {})
        @missing = missing
        @context = context
        super(message)
      end
    end

    FunctionEntry = Struct.new(
      :name, :kind, :signatures, :kernel, :variadic, :zip_policy, :null_policy, :identity, :summary, :dtypes,
      keyword_init: true
    ) do
      def eachwise?  = kind == :eachwise
      def aggregate? = kind == :aggregate
    end

    # Each-wise: element-by-element (with broadcast of scalars by the compiler/runtime).
    # Defaults: signatures ["()->()", "(i)->(i)"], null_policy :propagate, zip_policy :zip
    def self.define_eachwise(name, &block)
      name = name.to_s
      builder = EachwiseBuilder.new(name)
      yield(builder) if block_given?
      entry = builder.build!
      register_custom!(entry)
      entry
    end

    # Aggregate: reducers over the last axis.
    # Defaults: signatures ["(i)->()"], null_policy :skip
    # Requires: identity (for empty inputs) and kernel
    def self.define_aggregate(name, &block)
      name = name.to_s
      builder = AggregateBuilder.new(name)
      yield(builder) if block_given?
      entry = builder.build!
      register_custom!(entry)
      entry
    end

    def self.custom_functions
      @custom_functions ||= {}
    end

    private

    def self.register_custom!(entry)
      @mutex ||= Mutex.new
      @custom_functions ||= {}
      @mutex.synchronize do
        if @custom_functions.key?(entry.name)
          raise BuildError.new(
            "Function name already registered: #{entry.name}",
            context: { name: entry.name }
          )
        end
        @custom_functions[entry.name] = entry
        # Clear caches so new function is picked up
        @registry_v2 = nil
        @functions_cache = nil
      end
    end

    def self.extract_return_type(function)
      # Extract return type from dtypes.result field
      result_dtype = function.dtypes["result"] || function.dtypes[:result]
      return Core::Types.infer_from_dtype(result_dtype) if result_dtype

      # No fallback - if dtypes.result is not specified, return :any
      :any
    end

    def self.extract_param_types(function)
      # Extract parameter types from function metadata if available
      # For now, return empty array since the TypeChecker doesn't rely heavily on this
      # The real type checking happens via NEP-20 signatures in FunctionSignaturePass
      []
    end
  end
end
