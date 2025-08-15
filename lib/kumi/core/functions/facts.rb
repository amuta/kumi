# frozen_string_literal: true

module Kumi
  module Core
    module Functions
      # Thin wrapper that exposes algebraic facts from RegistryV2
      # Used by passes like UnsatDetector to avoid hardcoded function name checking
      class Facts
        def initialize(registry)
          @registry = registry
        end

        # Resolve a CallExpression to a Function entry
        def resolve_call(call, node_index)
          qname =
            node_index&.dig(call.object_id, :metadata, :qualified_name) ||
            node_index&.dig(call.object_id, :metadata, :effective_fn_name) ||
            call.fn_name
          
          @registry.resolve(qname.to_s, arity: call.args.size)
        rescue KeyError
          nil
        end

        # ---- Roles / kinds ----

        def role_of(call, node_index)
          fn = resolve_call(call, node_index)
          return nil unless fn
          
          # Prefer explicit algebra.role; fall back to function class
          # Convert string role to symbol for consistency
          role = fn.algebra[:role]
          role = role.to_sym if role.is_a?(String)
          role || fn.class_sym
        end

        def comparator?(call, node_index)
          fn = resolve_call(call, node_index)
          return false unless fn
          
          # Check for comparison semantics or legacy algebra role
          (fn.semantics[:family] == 'comparison') || 
          (fn.algebra[:role]&.to_sym == :comparator)
        end

        def comparator_op(call, node_index)
          # One of :>, :<, :>=, :<=, :==, :!=
          fn = resolve_call(call, node_index)
          return nil unless fn
          
          # Infer operator from function name for new semantics-based comparisons
          if fn.semantics[:family] == 'comparison'
            case fn.name.to_s
            when /\.eq$/ then :==
            when /\.ne$/ then :!=
            when /\.lt$/ then :<
            when /\.le$/ then :<=
            when /\.gt$/ then :>
            when /\.ge$/ then :>=
            else call.fn_name&.to_sym
            end
          else
            # Legacy algebra-based approach
            op = fn.algebra[:comparator_op]
            op = op.to_sym if op.is_a?(String)
            op || call.fn_name&.to_sym
          end
        end

        def logical_kind(call, node_index)
          # :and | :or | :not | :cascade_and (if you keep it as a first-class op)
          fn = resolve_call(call, node_index)
          return nil unless fn
          
          # Check new algebra structure for boolean ops
          if fn.algebra[:family] == 'boolean_op'
            op = fn.algebra[:op]
            op = op.to_sym if op.is_a?(String)
            return op
          end
          
          # Legacy approach: check logical field
          logical = fn.algebra[:logical]
          logical = logical.to_sym if logical.is_a?(String)
          logical
        end

        def boolean_aggregate?(call, node_index)
          fn = resolve_call(call, node_index)
          return false unless fn
          
          (fn.class_sym == :aggregate) && (fn.algebra[:boolean_aggregate] || fn.name.to_s.match?(/any\?|none\?|all\?/))
        end
      end
    end
  end
end