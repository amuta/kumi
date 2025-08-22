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
        schedules = state[:ir_execution_schedules] || {}

        accessors = Dev::Profiler.phase("compiler.access_builder") do
          Kumi::Core::Compiler::AccessBuilder.build(access_plans)
        end

        access_meta = {}

        # access_plans.each_value do |plans|
        #   plans.each do |p|
        #     access_meta[p.accessor_key] = { mode: p.mode, scope: p.scope }

        #     # Build precise field -> plan_ids mapping for invalidation
        #     root_field = p.accessor_key.to_s.split(":").first.split(".").first.to_sym
        #     field_to_plan_ids[root_field] << p.accessor_key
        #   end
        # end

        # Use the internal functions hash that VM expects
        registry ||= Kumi::Registry.functions
        new(ir: ir, accessors: accessors, access_meta: access_meta, registry: registry,
            input_metadata: input_metadata, dependents: dependents,
            schema_name: schema_name, schedules: schedules)
      end

      def initialize(ir:, accessors:, access_meta:, registry:, input_metadata:, dependents: {}, schedules: {}, schema_name: nil)
        @ir = ir.freeze
        @acc = accessors.freeze
        @meta = access_meta.freeze
        @reg = registry
        @input_metadata = input_metadata.freeze
        @dependents = dependents.freeze
        @schema_name = schema_name
        @schedules = schedules
        @decl = @ir.decls.map { |d| [d.name, d] }.to_h
        @accessor_cache = {} # Persistent accessor cache across evaluations
      end

      def decl?(name) = @decl.key?(name)

      def read(input, mode: :ruby)
        Run.new(self, input, mode: mode, input_metadata: @input_metadata, dependents: @dependents, declarations: @decl.keys)
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

      def eval_decl(name, input, mode: :ruby, declaration_cache: {})
        raise Kumi::Core::Errors::RuntimeError, "unknown decl #{name}" unless decl?(name)

        schedule = @schedules[name]
        # If the caller asked for a specific binding, schedule deps once

        runtime = {
          accessor_cache: @accessor_cache,
          declaration_cache: declaration_cache, # run-local cache
          schema_name: @schema_name,
          target: name
        }

        out = Dev::Profiler.phase("vm.run", target: name) do
          Kumi::Core::IR::ExecutionEngine.run(schedule, input: input, runtime: runtime, accessors: @acc, registry: @reg).fetch(name)
        end

        mode == :ruby ? unwrap(@decl[name], out) : out
      end

      def unwrap(_decl, v)
        v[:k] == :scalar ? v[:v] : v # no grouping needed
      end

      private

      def validate_keys(keys)
        unknown_keys = keys - @decl.keys
        return keys if unknown_keys.empty?

        raise Kumi::Errors::RuntimeError, "No binding named #{unknown_keys.first}"
      end
    end
  end
end
