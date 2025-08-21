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
      def self.from_analysis(state, registry: nil, schema_name: nil)
        ir = state.fetch(:ir_module)
        access_plans = state.fetch(:access_plans)
        input_metadata = state[:input_metadata] || {}
        dependents = state[:dependents] || {}
        ir_dependencies = state[:ir_dependencies] || {} # <-- from IR dependency pass
        name_index = state[:name_index] || {} # <-- from IR dependency pass
        accessors = Dev::Profiler.phase("compiler.access_builder") do
          Kumi::Core::Compiler::AccessBuilder.build(access_plans)
        end

        access_meta = {}
        field_to_plan_ids = Hash.new { |h, k| h[k] = [] }

        access_plans.each_value do |plans|
          plans.each do |p|
            access_meta[p.accessor_key] = { mode: p.mode, scope: p.scope }

            # Build precise field -> plan_ids mapping for invalidation
            root_field = p.accessor_key.to_s.split(":").first.split(".").first.to_sym
            field_to_plan_ids[root_field] << p.accessor_key
          end
        end

        # Use the internal functions hash that VM expects
        registry ||= Kumi::Registry.functions
        new(ir: ir, accessors: accessors, access_meta: access_meta, registry: registry,
            input_metadata: input_metadata, field_to_plan_ids: field_to_plan_ids, dependents: dependents,
            ir_dependencies: ir_dependencies, name_index: name_index, schema_name: schema_name)
      end

      def initialize(ir:, accessors:, access_meta:, registry:, input_metadata:, field_to_plan_ids: {}, dependents: {}, ir_dependencies: {},
                     name_index: {}, schema_name: nil)
        @ir = ir.freeze
        @acc = accessors.freeze
        @meta = access_meta.freeze
        @reg = registry
        @input_metadata = input_metadata.freeze
        @field_to_plan_ids = field_to_plan_ids.freeze
        @dependents = dependents.freeze
        @ir_dependencies = ir_dependencies.freeze # decl -> [stored_bindings_it_references]
        @name_index = name_index.freeze # store_name -> producing decl
        @schema_name = schema_name
        @decl = @ir.decls.map { |d| [d.name, d] }.to_h
        @accessor_cache = {} # Persistent accessor cache across evaluations
      end

      def decl?(name) = @decl.key?(name)

      def read(input, mode: :ruby)
        Run.new(self, input, mode: mode, input_metadata: @input_metadata, dependents: @dependents)
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

      def eval_decl(name, input, mode: :ruby, declaration_cache: nil)
        raise Kumi::Core::Errors::RuntimeError, "unknown decl #{name}" unless decl?(name)

        # If the caller asked for a specific binding, schedule deps once
        decls_to_run = topo_closure_for_target(name)

        vm_context = {
          input: input,
          accessor_cache: @accessor_cache,
          declaration_cache: declaration_cache || {}, # run-local cache
          decls_to_run: decls_to_run,                # <-- explicit schedule
          strict_refs: true,                         # <-- refs must be precomputed
          name_index: @name_index,                   # for error messages, twins, etc.
          schema_name: @schema_name
        }

        out = Dev::Profiler.phase("vm.run", target: name) do
          Kumi::Core::IR::ExecutionEngine.run(@ir, vm_context, accessors: @acc, registry: @reg).fetch(name)
        end

        mode == :ruby ? unwrap(@decl[name], out) : out
      end

      def clear_field_accessor_cache(field_name)
        # Use precise field -> plan_ids mapping for exact invalidation
        plan_ids = @field_to_plan_ids[field_name] || []
        # Cache keys are [plan_id, input_object_id] arrays
        @accessor_cache.delete_if { |(pid, _), _| plan_ids.include?(pid) }
      end

      def unwrap(_decl, v)
        v[:k] == :scalar ? v[:v] : v # no grouping needed
      end

      def topo_closure_for_target(store_name)
        target_decl = @name_index[store_name]
        raise "Unknown target store #{store_name}" unless target_decl

        # DFS collect closure of decl names using pre-computed IR-level dependencies
        seen = {}
        order = []
        visiting = {}

        visit = lambda do |dname|
          return if seen[dname]
          raise "Cycle detected in DAG scheduler: #{dname}. Mutual recursion should be caught earlier by UnsatDetector." if visiting[dname]

          visiting[dname] = true

          # Visit declarations that produce the bindings this decl references
          Array(@ir_dependencies[dname]).each do |ref_binding|
            # Find which declaration produces this binding
            producer = @name_index[ref_binding]
            visit.call(producer.name) if producer
          end

          visiting.delete(dname)
          seen[dname] = true
          order << dname
        end

        visit.call(target_decl.name)

        # 'order' is postorder; it already yields producers before consumers
        order.map { |dname| @decl[dname] }
      end

      private

      def validate_keys(keys)
        unknown_keys = keys - @decl.keys
        return keys if unknown_keys.empty?

        raise Kumi::Errors::RuntimeError, "No binding named #{unknown_keys.first}"
      end
    end

    class Run
      def initialize(program, input, mode:, input_metadata:, dependents:)
        @program = program
        @input = input
        @mode = mode
        @input_metadata = input_metadata
        @dependents = dependents
        @cache = {}
      end

      def get(name)
        unless @cache.key?(name)
          # Get the result in VM internal format
          vm_result = @program.eval_decl(name, @input, mode: :wrapped, declaration_cache: @cache)
          # Store VM format for cross-VM caching
          @cache[name] = vm_result
        end

        # Convert to requested format when returning
        vm_result = @cache[name]
        @mode == :wrapped ? vm_result : @program.unwrap(nil, vm_result)
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

      def method_missing(sym, *args, **kwargs, &)
        return super unless args.empty? && kwargs.empty? && @program.decl?(sym)

        get(sym)
      end

      def respond_to_missing?(sym, priv = false)
        @program.decl?(sym) || super
      end

      def update(**changes)
        affected_declarations = Set.new

        changes.each do |field, value|
          # Validate field exists
          raise ArgumentError, "unknown input field: #{field}" unless input_field_exists?(field)

          # Validate domain constraints
          validate_domain_constraint(field, value)

          # Update the input data IN-PLACE to preserve object_id for cache keys
          @input[field] = value

          # Clear accessor cache for this specific field
          @program.clear_field_accessor_cache(field)

          # Collect all declarations that depend on this input field
          field_dependents = @dependents[field] || []
          affected_declarations.merge(field_dependents)
        end

        # Only clear cache for affected declarations, not all declarations
        affected_declarations.each { |decl| @cache.delete(decl) }

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
    end
  end
end
