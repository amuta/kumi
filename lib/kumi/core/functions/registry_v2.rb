module Kumi::Core::Functions
  # Represents an ambiguous function that needs type-based resolution
  class AmbiguousFunction
    attr_reader :name, :candidates
    
    def initialize(name, candidates)
      @name = name
      @candidates = candidates
    end
    
    def ambiguous?
      true
    end
    
    # Resolve ambiguity based on argument types
    def resolve_with_types(arg_types)
      # Try to find the best candidate based on argument types
      # For now, simple heuristic: if first arg is string-like, prefer string functions
      if arg_types && arg_types.first == :string
        string_candidate = @candidates.find { |f| f.name.start_with?("string.") }
        return string_candidate if string_candidate
      end
      
      # If no clear winner, raise the ambiguity error
      raise KeyError, "ambiguous function #{@name} (candidates: #{@candidates.map(&:name).join(', ')}); use a qualified name or provide type hints"
    end
    
    # Delegate other methods to first candidate for compatibility
    def method_missing(method, *args, &block)
      @candidates.first.send(method, *args, &block)
    end
    
    def respond_to_missing?(method, include_private = false)
      @candidates.first.respond_to?(method, include_private)
    end
  end

  class RegistryV2
    # Global caching to avoid repeated YAML loading
    @global_cache = {}
    @cache_mutex = Mutex.new

    def initialize(functions:)
      @by_qualified = {}
      @by_basename = {}

      functions.each do |func|
        # Store by fully qualified name
        @by_qualified[func.name] = func

        # Store by basename for overload resolution
        basename = func.name.split(".").last
        @by_basename[basename] ||= []
        @by_basename[basename] << func
      end

      @by_qualified.freeze
      @by_basename.freeze
    end

    # Factory method to load from YAML configuration with global caching
    def self.load_from_file(path = nil)
      default_path = File.join(__dir__, "../../../..", "config", "functions.yaml")
      path ||= default_path

      # Use global caching to avoid repeated YAML parsing
      @cache_mutex.synchronize do
        cache_key = File.absolute_path(path)
        @global_cache[cache_key] ||= begin
          functions = Loader.load_file(path)
          new(functions: functions)
        end
      end
    end

    # Clear global cache for testing/development
    def self.clear_cache!
      @cache_mutex.synchronize { @global_cache.clear }
    end

    def resolve(name, arg_types: nil, arity: nil)
      q = name.to_s
      if q.include?(".")
        fn = @by_qualified[q] or raise KeyError, "unknown function #{q}"
        check_arity!(fn, arity) if arity
        return fn
      end

      cands = Array(@by_basename[q])
      raise KeyError, "unknown function #{q}" if cands.empty?

      # Filter by arity if provided
      if arity
        cands = cands.select { |f| arity_compatible?(f, arity) }
        raise KeyError, "no overload of #{q} matches arity #{arity}" if cands.empty?
      end

      # Return single candidate or ambiguous result for deferred resolution
      if cands.length == 1
        cands.first
      else
        # Return an AmbiguousFunction object that stores all candidates
        AmbiguousFunction.new(q, cands)
      end
    end

    def fetch(name, opset: nil, **kw)
      # Legacy compatibility - ignore opset for now, use resolve
      resolve(name, **kw)
    end

    # Get function signatures for NEP-20 signature resolution
    # This bridges RegistryV2 with our existing SignatureResolver
    def get_function_signatures(name, opset: nil)
      fn = fetch(name, opset: opset)
      # Convert Signature objects to string representations for NEP-20 parser
      fn.signatures.map(&:to_signature_string)
    rescue KeyError
      [] # Function not found in RegistryV2
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

    # Direct kernel execution - eliminates need for runtime registry!
    def get_executable_kernel(fn_name, backend: :ruby, conditions: {})
      function = resolve(fn_name)
      kernel_entry = resolve_kernel(function, backend: backend, conditions: conditions)
      KernelAdapter.build_for(function, kernel_entry).callable
    end

    # Introspection methods
    def all_function_names
      @by_qualified.keys
    end

    def function_exists?(name, **kw)
      resolve(name, **kw)
      true
    rescue KeyError
      false
    end

    def all_functions
      @by_qualified.values
    end

    private

    def arity_compatible?(func, arity)
      # Check if function arity is compatible with given arity
      func_arity = func.respond_to?(:arity) ? func.arity : -1
      return true if func_arity == -1 # Variable arity

      func_arity == arity
    end

    def check_arity!(func, arity)
      return if arity_compatible?(func, arity)

      func_arity = func.respond_to?(:arity) ? func.arity : "unknown"
      raise KeyError, "arity mismatch for #{func.name}: expected #{func_arity}, got #{arity}"
    end
  end
end
