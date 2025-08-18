# frozen_string_literal: true

module Kumi
  module Registry
    # Composite registry that checks custom functions first, then delegates to RegistryV2
    class CompositeRegistry
      def initialize(base_registry, custom_registry_module)
        @base_registry = base_registry
        @custom_registry = custom_registry_module
      end

      def resolve(name, arg_types: nil, arity: nil)
        # Check custom functions first
        if custom_fn = resolve_custom_function(name, arity)
          return custom_fn
        end
        
        # Delegate to base RegistryV2
        @base_registry.resolve(name, arg_types: arg_types, arity: arity)
      end

      def function_exists?(name, arity: nil)
        # Check custom functions first
        custom_functions = @custom_registry.custom_functions
        return true if custom_functions.key?(name.to_s)
        
        # Delegate to base registry
        @base_registry.function_exists?(name, arity: arity)
      end

      def all_function_names
        custom_names = @custom_registry.custom_functions.keys
        base_names = @base_registry.all_function_names
        (custom_names + base_names).uniq
      end

      def get_executable_kernel(name)
        # Check custom functions first
        custom_functions = @custom_registry.custom_functions
        if entry = custom_functions[name.to_s]
          return entry.kernel
        end
        
        # Delegate to base registry
        @base_registry.get_executable_kernel(name)
      end

      def get_function_signatures(name)
        # Check custom functions first
        custom_functions = @custom_registry.custom_functions
        if entry = custom_functions[name.to_s]
          # Convert to CustomFunction and get signatures the same way as RegistryV2
          custom_fn = convert_custom_function_to_registry_v2(entry)
          return custom_fn.signatures.map(&:to_signature_string)
        end
        
        # Delegate to base registry
        @base_registry.get_function_signatures(name)
      end

      # Delegate other methods to base registry
      def method_missing(method, *args, &block)
        @base_registry.public_send(method, *args, &block)
      end

      def respond_to_missing?(method, include_private = false)
        @base_registry.respond_to?(method, include_private)
      end

      private

      def resolve_custom_function(name, arity)
        custom_functions = @custom_registry.custom_functions
        entry = custom_functions[name.to_s]
        return nil unless entry
        
        # Convert custom function entry to RegistryV2 Function format
        convert_custom_function_to_registry_v2(entry)
      end

      def convert_custom_function_to_registry_v2(entry)
        # Create a minimal Function-like object that works with RegistryV2
        CustomFunction.new(
          name: entry.name,
          qualified_name: entry.name,
          class_sym: entry.kind,  # :eachwise or :aggregate
          signatures_data: entry.signatures,
          kernel: entry.kernel,
          arity: detect_arity_from_kernel(entry.kernel),
          variadic: entry.variadic,
          dtypes_data: entry.dtypes
        )
      end

      def detect_arity_from_kernel(kernel)
        # Try to detect arity from the kernel proc
        return kernel.arity if kernel.respond_to?(:arity)
        return -1  # Variadic fallback
      end
    end

    # Minimal Function-like class for custom functions
    class CustomFunction
      attr_reader :name, :qualified_name, :class_sym, :arity, :variadic, :kernel

      def initialize(name:, qualified_name:, class_sym:, signatures_data:, kernel:, arity:, variadic:, dtypes_data:)
        @name = name
        @qualified_name = qualified_name
        @class_sym = class_sym
        @signatures_data = signatures_data
        @kernel = kernel
        @arity = arity
        @variadic = variadic
        @dtypes_data = dtypes_data
      end

      def signatures
        # Convert signature strings to Signature objects for compatibility
        @signatures ||= @signatures_data.map do |sig_str|
          Core::Functions::Loader.parse_signature(sig_str)
        end
      end

      def dtypes
        # Use the dtypes specified in the function builder
        @dtypes_data
      end
    end
  end
end