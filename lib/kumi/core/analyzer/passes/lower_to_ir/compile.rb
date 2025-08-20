# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module LowerToIR
          module Compile
            def compile_decl(name, decl, access_plans, scope_plans, node_index, errors)
              @ops = []
              @temp_seq = 0
              @errors = errors

              target_scope = Array(scope_plans.dig(name, :scope))
              # Use explicit annotation from JoinReducePlanningPass instead of fallback logic
              needs_indices = scope_plans["#{name}:needs_indices"] || false
              slot = compile_expr(decl.expression, access_plans, scope_plans, node_index,
                                  need_indices: needs_indices, required_scope: target_scope)

              return nil if slot.nil? # Error occurred during compilation

              # Twin creation is unnecessary - SWITCH operations already produce correct vector results
              # Vector cascade compilation handles both scalar and vector results properly
              emit_store(name, slot)

              kind = decl.is_a?(Syntax::ValueDeclaration) ? :value : :trait
              # Shape determination: check if this declaration has vector target scope
              target_scope = Array(scope_plans.dig(name, :scope))
              shape = target_scope.empty? ? :scalar : :vec
              Kumi::Core::IR::Decl.new(name: name, kind: kind, shape: shape, ops: @ops)
            end

            def compile_expr(node, access_plans, scope_plans, node_index, need_indices:, required_scope:, cacheable: true)
              cache_key = [@current_decl, node.object_id, required_scope, need_indices]
              return @cache[cache_key] if cacheable && @cache.key?(cache_key)

              slot = case node
                     when Syntax::Literal
                       emit_const(node.value)

                     when Syntax::InputReference, Syntax::InputElementReference
                       key, scope, is_scalar, has_idx = access_mode_for_input(node, access_plans, node_index, need_indices: need_indices)
                       emit_load_input(key, scope: scope, is_scalar: is_scalar, has_idx: has_idx)

                     when Syntax::DeclarationReference
                       # Always reference the base declaration name
                       # The VM will handle broadcasting from scalar to vector contexts automatically
                       puts "DEBUG: DeclarationReference #{node.name} -> REF #{node.name}" if ENV["DEBUG_LOWER"]
                       emit_ref(node.name)

                     when Syntax::ArrayExpression
                       elems = node.elements.map { |e| compile_expr(e, access_plans, scope_plans, node_index, need_indices: false, required_scope: []) }
                       emit_array(elems)

                     when Syntax::CascadeExpression
                       # Handle both scalar and vector cascades
                       scope = Array(scope_plans.dig(@current_decl, :scope))
                       if scope.empty?
                         compile_scalar_cascade(node, access_plans, scope_plans, node_index)
                       else
                         compile_vector_cascade(node, access_plans, scope_plans, node_index, scope)
                       end

                     when Syntax::CallExpression
                       compile_call(node, access_plans, scope_plans, node_index, required_scope: required_scope)

                     else
                       @errors << Core::ErrorReporter.create_error(
                         "Unknown AST node: #{node.class}",
                         location: node.respond_to?(:loc) ? node.loc : nil,
                         type: :developer
                       )
                       return nil
                     end

              @cache[cache_key] = slot if cacheable
              slot
            end

            def compile_call(call, access_plans, scope_plans, node_index, required_scope:)
              meta = require_call_contract!(node_index, call, @errors)
              return nil if meta.nil?

              # Handle cascade_and identity transformation
              if call.fn_name == :cascade_and && meta.dig(:metadata, :desugar_to_identity)
                identity_arg = meta.dig(:metadata, :identity_arg)
                return compile_expr(identity_arg, access_plans, scope_plans, node_index,
                                    need_indices: false, required_scope: required_scope)
              end

              # Handle cascade_and chained AND transformation
              if call.fn_name == :cascade_and && meta.dig(:metadata, :desugar_to_chained_and)
                # Chain multiple arguments into nested binary AND calls: and(a, and(b, c))
                return compile_chained_and(call.args, access_plans, scope_plans, node_index, required_scope)
              end

              plan = meta[:join_plan]

              # 1) compile args with per-arg indexing requirement
              arg_slots = call.args.each_with_index.map do |arg, idx|
                need_idx = Array(plan[:requires_indices])[idx] ? true : false
                compile_expr(arg, access_plans, scope_plans, node_index,
                             need_indices: need_idx, required_scope: [])
              end

              # 2) apply explicit lifts from plan
              # COMMENTED OUT: Let map operations handle scalar propagation automatically
              # aligned = arg_slots.each_with_index.map do |slot, idx|
              #   lifts = Array(plan[:lifts])[idx] || []
              #   cur = slot
              #   lifts.each { cur = emit_lift(plan[:target_scope], cur) }
              #   cur
              # end
              aligned = arg_slots  # Use args directly without explicit lifts

              # 3) emit op
              qualified_name = meta[:metadata][:qualified_name] || call.fn_name
              case plan[:policy]
              when :zip, :broadcast
                emit_map(qualified_name, *aligned)
              when :reduce
                axis = plan[:axis] || []
                # Pass all arguments to reduce operation - first is the vector, rest are scalars
                emit_reduce(qualified_name, axis, plan[:target_scope], plan[:flatten_args], *aligned)
              else
                @errors << Core::ErrorReporter.create_error(
                  "Unknown join policy: #{plan[:policy].inspect}",
                  location: call.respond_to?(:loc) ? call.loc : nil,
                  type: :developer
                )
                return nil
              end
            end

            def compile_scalar_cascade(node, access_plans, scope_plans, node_index)
              any_prev = emit_const(false)
              cases_attr = []

              node.cases.each do |c|
                not_prev = emit_map("core.not", any_prev)
                cond     = compile_expr(c.condition, access_plans, scope_plans, node_index, need_indices: false, required_scope: nil, cacheable: false)
                guard    = emit_map("core.and", not_prev, cond)
                emit_guard_push(guard)
                val_slot = compile_expr(c.result, access_plans, scope_plans, node_index, need_indices: false, required_scope: nil, cacheable: false)
                emit_guard_pop
                cases_attr << [cond, val_slot]
                any_prev = emit_map("core.or", any_prev, cond)
              end

              default_expr = node.cases.find { |cc| cc.condition.is_a?(Syntax::Literal) && cc.condition.value == true }&.result || Syntax::Literal.new(nil)
              not_prev = emit_map("core.not", any_prev)
              emit_guard_push(not_prev)
              default_slot = compile_expr(default_expr, access_plans, scope_plans, node_index, need_indices: false, required_scope: nil, cacheable: false)
              emit_guard_pop

              emit_switch(cases_attr, default_slot)
            end

            def compile_vector_cascade(node, access_plans, scope_plans, node_index, target_scope)
              # For vectorized cascades, build result element-wise using MAP operations
              # instead of relying on SWITCH operation which doesn't handle vectors properly
              
              # Start with default value for all elements
              default_expr = node.cases.find { |cc| cc.condition.is_a?(Syntax::Literal) && cc.condition.value == true }&.result || Syntax::Literal.new(nil)
              # FIXED: Use need_indices: true for vectorized context to get element-wise access
              result = compile_expr(default_expr, access_plans, scope_plans, node_index, need_indices: true, required_scope: target_scope, cacheable: false)
              
              # Process cases in reverse order so first matching condition wins
              node.cases.reverse.each do |c|
                # FIXED: Use need_indices: true for vectorized context to get element-wise access
                cond = compile_expr(c.condition, access_plans, scope_plans, node_index, need_indices: true, required_scope: target_scope, cacheable: false)
                val = compile_expr(c.result, access_plans, scope_plans, node_index, need_indices: true, required_scope: target_scope, cacheable: false)
                
                # Use conditional selection: where(condition, true_value, false_value)
                # This applies element-wise: result[i] = cond[i] ? val[i] : result[i]
                result = emit_map("mask.where", cond, val, result)
              end
              
              result
            end

            def compile_chained_and(args, access_plans, scope_plans, node_index, required_scope)
              # Compile all arguments first
              compiled_args = args.map do |arg|
                compile_expr(arg, access_plans, scope_plans, node_index,
                             need_indices: false, required_scope: required_scope)
              end

              # Chain them into nested binary AND operations: and(a, and(b, c))
              # For N args, we need N-1 nested AND calls
              # Single arg case: reduce just returns the single argument unchanged
              compiled_args.reverse.reduce do |acc, arg|
                emit_map("core.and", arg, acc)
              end
            end

          end
        end
      end
    end
  end
end