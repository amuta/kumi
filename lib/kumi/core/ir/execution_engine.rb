# frozen_string_literal: true

module Kumi
  module Core
    module IR
      # ExecutionEngine interpreter for IR execution
      #
      # ARCHITECTURE:
      # - Values:
      #   * Scalar(v)                    → { k: :scalar, v: v }
      #   * Vec(scope, rows, has_idx)    → { k: :vec, scope: [:axis, ...], rows: [{ v:, idx:[...] }, ...], has_idx: true/false }
      #     - Rank = idx length; scope length is the logical axes carried by the vector
      #
      # - Combinators (pure, stateless, delegate to Executor):
      #   * broadcast_scalar(scalar, vec)        → replicate scalar across vec rows (preserves idx/scope)
      #   * zip_same_scope(vec1, vec2, ...)      → positional zip for equal scope & equal row count
      #   * align_to(tgt_vec, src_vec, to_scope) → expand src by prefix indices to match a higher-rank scope
      #   * group_rows(rows, depth)              → stable grouping by idx prefix to nested Ruby arrays
      #
      # - Executor:
      #   * Executes IR ops in order; delegates to combinators; maintains a slot stack
      #   * No structural inference; trusts IR attributes (scope, has_idx, is_scalar)
      #
      # OP SEMANTICS (subset):
      # - const(value)               → push Scalar(value)
      # - ref(name)                  → push previous slot by stored name (twins allowed: :name__vec)
      # - load_input(plan_id, attrs) → call accessor; return Scalar or Vec according to attrs/mode
      # - map(fn, argc, *args)       → elementwise or scalar call; auto alignment already handled by IR
      # - reduce(fn, axis, ...)      → reduce one vector arg; returns Scalar
      # - align_to(to_scope, a, b)   → align b to a’s to_scope (prefix-compat only)
      # - array(count, *args)        → collect args into a Scalar(Array)
      # - lift(to_scope, slot)       → require Vec(has_idx), group rows with `group_rows` to nested Scalar
      # - store(name, slot)          → bind slot to name in env (used for :name and :name__vec twins)
      #
      # PRINCIPLES:
      # - Mechanical execution only; “smarts” live in LowerToIR.
      # - Never sniff Ruby types to guess shapes.
      # - Errors early and clearly if invariants are violated (e.g., align_to expects vecs with indices).
      #
      # DEBUGGING:
      # - DEBUG_VM_ARGS=1 prints per-op execution and arguments.
      # - DEBUG_GROUP_ROWS=1 prints grouping decisions during Lift.
      module ExecutionEngine
        def self.run(ir_module, ctx, accessors:, registry:)
          # Use persistent accessor cache if available, otherwise create temporary one
          if ctx[:accessor_cache]
            # Include input data in cache key to avoid cross-context pollution
            input_key = ctx[:input]&.hash || ctx["input"]&.hash || 0
            memoized_accessors = add_persistent_memoization(accessors, ctx[:accessor_cache], input_key)
          else
            memoized_accessors = add_temporary_memoization(accessors)
          end
          
          Interpreter.run(ir_module, ctx, accessors: memoized_accessors, registry: registry)
        end

        private

        def self.add_persistent_memoization(accessors, cache, input_key)
          accessors.map do |plan_id, accessor_fn|
            [plan_id, lambda do |input_data|
              cache_key = [plan_id, input_key]
              cache[cache_key] ||= accessor_fn.call(input_data)
            end]
          end.to_h
        end

        def self.add_temporary_memoization(accessors)
          cache = {}
          accessors.map do |plan_id, accessor_fn|
            [plan_id, lambda do |input_data|
              cache[plan_id] ||= accessor_fn.call(input_data)
            end]
          end.to_h
        end
      end
    end
  end
end
