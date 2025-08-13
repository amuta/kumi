# frozen_string_literal: true

module Kumi
  module Runtime
    # Executable / Reader: evaluation interface for compiled schemas
    #
    # BUILD:
    # - Executable.from_analysis(state) consumes:
    #   * :ir_module (lowered IR)
    #   * :access_plans (for AccessBuilder)
    #   * function registry
    # - Builds accessor lambdas once per plan id.
    #
    # EVALUATION:
    # - program.read(inputs, mode: :public|:wrapped, target: nil)
    #   * mode=:public  → returns “user values” (scalars and plain Ruby arrays). Vec results are exposed as their lifted scalar.
    #   * mode=:wrapped → returns internal VM structures for introspection:
    #       - Scalars as {k: :scalar, v: ...}
    #       - Vec twins available as :name__vec (and :name for lifted scalar)
    #   * target: symbol → short-circuit after computing the requested declaration and its dependencies.
    #
    # NAMING & TWINS (TODO: we are not exposing for now):
    # - Every vectorized declaration with indices has:
    #   * :name__vec  → internal vec form (rows with idx)
    #   * :name       → lifted scalar form (nested arrays shaped by scope)
    # - only :name is visible (TODO: For now, we do not expose the twins)
    #
    # CACHING / MEMOIZATION:
    # - Values are computed once per evaluation; dependent requests reuse cached slots.
    #
    # ERROR SURFACE:
    # - VM errors are wrapped as Kumi::Core::Errors::RuntimeError with op context (decl/op index).
    # - Accessors raise descriptive KeyError for missing fields/arrays (policy-aware).
    #
    # DEBUGGING:
    # - DEBUG_LOWER=1 to print IR at build time
    # - DEBUG_VM_ARGS=1 to trace VM execution
    # - Accessors can be debugged independently with DEBUG_ACCESSOR_OPS=1
    class Executable
      def self.from_analysis(state, registry: nil)
        ir = state.fetch(:ir_module)
        access_plans = state.fetch(:access_plans)
        input_metadata = state[:input_metadata] || {}
        accessors = Kumi::Core::Compiler::AccessBuilder.build(access_plans)

        access_meta = {}
        access_plans.each_value do |plans|
          plans.each do |p|
            access_meta[p.accessor_key] = { mode: p.mode, scope: p.scope }
          end
        end

        # Use the internal functions hash that VM expects
        registry ||= Kumi::Registry.functions
        new(ir: ir, accessors: accessors, access_meta: access_meta, registry: registry, input_metadata: input_metadata)
      end

      def initialize(ir:, accessors:, access_meta:, registry:, input_metadata:)
        @ir = ir.freeze
        @acc = accessors.freeze
        @meta = access_meta.freeze
        @reg = registry
        @input_metadata = input_metadata.freeze
        @decl = @ir.decls.map { |d| [d.name, d] }.to_h
      end

      def decl?(name) = @decl.key?(name)

      def read(input, mode: :ruby)
        Run.new(self, input, mode: mode, input_metadata: @input_metadata)
      end

      # API compatibility for backward compatibility
      def evaluate(ctx, *key_names)
        target_keys = key_names.empty? ? @decl.keys : validate_keys(key_names)

        # Handle context wrapping for backward compatibility  
        input = ctx.respond_to?(:ctx) ? ctx.ctx : ctx

        target_keys.each_with_object({}) do |key, result|
          result[key] = eval_decl(key, input, mode: :ruby)
        end
      end

      def eval_decl(name, input, mode: :ruby)
        raise Kumi::Core::Errors::RuntimeError, "unknown decl #{name}" unless decl?(name)

        out = Kumi::Core::IR::ExecutionEngine.run(@ir, { input: input, target: name },
                                              accessors: @acc, registry: @reg).fetch(name)

        mode == :ruby ? unwrap(@decl[name], out) : out
      end

      private

      def validate_keys(keys)
        unknown_keys = keys - @decl.keys
        return keys if unknown_keys.empty?

        raise Kumi::Errors::RuntimeError, "No binding named #{unknown_keys.first}"
      end

      private

      def unwrap(_decl, v)
        v[:k] == :scalar ? v[:v] : v # no grouping needed
      end
    end

    class Run
      def initialize(program, input, mode:, input_metadata:)
        @program = program
        @input = input
        @mode = mode
        @input_metadata = input_metadata
        @cache = {}
      end

      def get(name)
        @cache[name] ||= @program.eval_decl(name, @input, mode: @mode)
      end

      def [](name)
        get(name)
      end

      def slice(*keys)
        return {} if keys.empty?
        keys.each_with_object({}) { |key, result| result[key] = get(key) }
      end

      def compiled_schema
        @program
      end

      def method_missing(sym, *args, **kwargs, &blk)
        return super unless args.empty? && kwargs.empty? && @program.decl?(sym)

        get(sym)
      end

      def respond_to_missing?(sym, priv = false)
        @program.decl?(sym) || super
      end

      def update(**changes)
        changes.each do |field, value|
          # Validate field exists
          raise ArgumentError, "unknown input field: #{field}" unless input_field_exists?(field)

          # Validate domain constraints
          validate_domain_constraint(field, value)

          # Update the input data
          @input = deep_merge(@input, { field => value })
        end

        # Clear cache after all updates
        @cache.clear
        self
      end

      def wrapped!
        @mode = :wrapped
        @cache.clear
        self
      end

      def ruby!
        @mode = :ruby
        @cache.clear
        self
      end

      private

      def input_field_exists?(field)
        # Check if field is declared in input block
        @input_metadata.key?(field) || @input.key?(field)
      end

      def validate_domain_constraint(field, value)
        field_meta = @input_metadata[field]
        return unless field_meta&.dig(:domain)

        domain = field_meta[:domain]
        return unless violates_domain?(value, domain)

        raise ArgumentError, "value #{value} is not in domain #{domain}"
      end

      def violates_domain?(value, domain)
        case domain
        when Range
          !domain.include?(value)
        when Array
          !domain.include?(value)
        when Proc
          # For Proc domains, we can't statically analyze
          false
        else
          false
        end
      end

      def deep_merge(a, b)
        return b unless a.is_a?(Hash) && b.is_a?(Hash)

        a.merge(b) { |_k, v1, v2| deep_merge(v1, v2) }
      end
    end
  end
end
