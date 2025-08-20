# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Plans per-declaration execution scope and join/lift needs.
        # Uses SignatureResolver as the source of truth for dimensional information.
        # No legacy broadcast heuristics - fails fast if signature plans missing.
        #
        # DEPENDENCIES: :declarations, :input_metadata, :node_index (with signature metadata)
        # PRODUCES: :scope_plans, :decl_shapes
        class ScopeResolutionPass < PassBase
          include Kumi::Core::Analyzer::Plans

          def run(_errors)
            @decls = get_state(:declarations, required: true)
            @node_index = get_state(:node_index, required: true)
            @input_meta = get_state(:input_metadata, required: true)

            @decl_scope = {}

            # Compute scope for each declaration using signature resolver as source of truth
            @decls.each_key { |name| scope_of_decl(name) }

            scope_plans = {}
            decl_shapes = {}

            @decls.each do |name, _|
              scope = @decl_scope[name] || []
              scope_plans[name] = Scope.new(scope: scope, lifts: [], join_hint: nil, arg_shapes: {})
              decl_shapes[name] = { scope: scope, result: scope.empty? ? :scalar : { array: :dense } }
            end

            populate_node_index_scopes

            state.with(:scope_plans, scope_plans.freeze)
                 .with(:decl_shapes, decl_shapes.freeze)
          end

          private

          def scope_of_decl(name)
            return @decl_scope[name] if @decl_scope.key?(name)

            expr = @decls[name].expression
            @decl_scope[name] = scope_of_expr(expr)
          end

          def scope_of_expr(expr)
            case expr
            when Kumi::Syntax::InputElementReference
              dims_from_path(expr.path)
            when Kumi::Syntax::InputReference
              dims_from_path([expr.name])
            when Kumi::Syntax::DeclarationReference
              scope_of_decl(expr.name)
            when Kumi::Syntax::CallExpression
              # Get scope from signature plan in node_index - fail if missing
              idx = @node_index[expr.object_id]
              raise "Missing node_index entry for CallExpression #{expr.fn_name}" unless idx
              # Check for signature metadata (result_axes from FunctionSignaturePass)
              if idx[:metadata] && idx[:metadata][:result_axes]
                Array(idx[:metadata][:result_axes])
              elsif idx[:inferred_scope]
                Array(idx[:inferred_scope])
              else
                raise "No signature plan found for CallExpression #{expr.fn_name} - FunctionSignaturePass must run first"
              end
            when Kumi::Syntax::ArrayExpression
              child_scopes = expr.elements.map { |e| scope_of_expr(e) }.uniq
              child_scopes.length == 1 ? child_scopes.first : []
            when Kumi::Syntax::CascadeExpression
              # For cascades, scope is the LUB (Least Upper Bound) of ALL expression scopes
              # Both conditions and results contribute to the cascade scope
              all_scopes = []
              expr.cases.each do |case_expr|
                all_scopes << scope_of_expr(case_expr.condition)
                all_scopes << scope_of_expr(case_expr.result)
              end
              all_scopes = all_scopes.compact.uniq
              # LUB logic: if all non-empty scopes are identical, use that scope
              # This ensures we can determine a definite scope when possible
              non_empty_scopes = all_scopes.reject(&:empty?)
              non_empty_scopes.length == 1 ? non_empty_scopes.first : []
            else
              []
            end
          end

          def dims_from_path(path)
            meta = @input_meta
            path.each do |seg|
              field = meta[seg] or raise "Input path not found: #{path.inspect}"
              return Array(field.dimensional_scope) if seg == path.last

              meta = field.children or raise "Missing children for #{seg} in #{path.inspect}"
            end
            []
          end

          def populate_node_index_scopes
            @node_index.each do |_, entry|
              next if entry[:inferred_scope]

              entry[:inferred_scope] =
                case entry[:type]
                when "CallExpression"
                  # Get scope from signature plan in node_index - fail if missing
                  if entry[:metadata] && entry[:metadata][:result_axes]
                    Array(entry[:metadata][:result_axes])
                  else
                    raise "No signature plan found for CallExpression #{entry[:node].fn_name} - FunctionSignaturePass must run first"
                  end
                when "InputReference", "InputElementReference"
                  node = entry[:node]
                  node.respond_to?(:path) ? dims_from_path(node.path) : dims_from_path([node.name])
                when "DeclarationReference"
                  scope_of_decl(entry[:node].name)
                when "ArrayExpression"
                  scope_of_expr(entry[:node])
                else
                  []
                end
            end
          end
        end
      end
    end
  end
end