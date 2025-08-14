module Kumi::Core::Functions
  class RegistryV2
    def initialize(functions:)
      @by_name = functions.group_by(&:name).transform_values { |v| v.sort_by(&:opset).freeze }.freeze
    end

    # Factory method to load from YAML configuration
    def self.load_from_file(path = nil)
      path ||= File.join(__dir__, "../../../..", "config", "functions.yaml")
      functions = Loader.load_file(path)
      new(functions: functions)
    end

    def fetch(name, opset: nil)
      list = @by_name[name] or raise KeyError, "unknown function #{name}"
      opset ? list.find { |f| f.opset == opset } : list.last
    end

    # Get function signatures for NEP-20 signature resolution
    # This bridges RegistryV2 with our existing SignatureResolver
    def get_function_signatures(name, opset: nil)
      begin
        fn = fetch(name, opset: opset)
        # Convert Signature objects to string representations for NEP-20 parser
        fn.signatures.map(&:to_signature_string)
      rescue KeyError
        []  # Function not found in RegistryV2 - fall back to legacy registry
      end
    end

    # Enhanced signature resolution using NEP-20 resolver
    def choose_signature(fn, arg_shapes)
      # Use our NEP-20 SignatureResolver for proper dimension handling
      sig_strings = fn.signatures.map(&:to_signature_string)
      parsed_sigs = sig_strings.map { |s| SignatureParser.parse(s) }
      
      plan = SignatureResolver.choose(signatures: parsed_sigs, arg_shapes: arg_shapes)
      
      # Return both the original function signature and the resolution plan
      {
        function: fn,
        signature: plan[:signature],
        plan: plan
      }
    rescue SignatureMatchError => e
      raise ArgumentError, "no matching signature for #{fn.name} with shapes #{arg_shapes.inspect}: #{e.message}"
    end

    def resolve_kernel(fn, backend:, conditions: {})
      ks = fn.kernels.select { |k| k.backend == backend.to_sym }
      ks = ks.select { |k| conditions.all? { |ck, cv| k.when_&.fetch(ck, cv) == cv } } unless conditions.empty?
      ks.max_by(&:priority) or raise "no kernel for #{fn.name} backend=#{backend}"
    end

    # Introspection methods
    def all_function_names
      @by_name.keys
    end

    def function_exists?(name)
      @by_name.key?(name)
    end

    def all_functions
      @by_name.values.flatten
    end
  end
end
