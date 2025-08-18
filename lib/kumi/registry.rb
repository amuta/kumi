# frozen_string_literal: true

module Kumi
  # Public facade for the function registry.
  # Bridges old Registry interface to RegistryV2 for backward compatibility.
  module Registry
    def self.registry_v2
      @registry_v2 ||= Core::Functions::RegistryV2.load_from_file
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
      # No-op for RegistryV2
    end

    private

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
