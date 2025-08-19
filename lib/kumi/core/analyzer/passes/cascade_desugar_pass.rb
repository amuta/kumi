# TODO: Compare this with lib/kumi/core/ir/lowering/cascade_lowerer.rb - maybe we can do that in here?
module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Desugar cascade_and syntax sugar into proper conditional logic
        # DEPENDENCIES: NameIndexer (needs node_index)
        # PRODUCES: Metadata marking cascade_and nodes for identity/AND transformation
        # INTERFACE: new(schema, state).run(errors)
        #
        # CASCADE_AND SEMANTICS:
        # - cascade_and(condition)           → IDENTITY (just evaluate condition)
        # - cascade_and(cond1, cond2, ...)   → BOOLEAN AND with short-circuit evaluation
        # - cascade_and()                    → SEMANTIC ERROR (at least one condition required)
        #
        # EXAMPLES:
        # - on t1, "big"       → condition: t1               → IR: ref {:name=>:t1}
        # - on t1, t2, "both"  → condition: core.and(t1, t2) → IR: guard-based short-circuit AND
        # - on cascade_and()   → SEMANTIC ERROR: "cascade_and requires at least one condition"
        #
        # NOTE: cascade_and is pure syntax sugar - no core.cascade_and function exists in registry
        class CascadeDesugarPass < PassBase
          def run(errors)
            ENV.fetch("DEBUG_CASCADE", nil) && puts("CascadeDesugarPass: Starting desugar pass")

            node_index = get_state(:node_index, required: true)

            # Traverse all declarations and their nested expressions
            declarations = get_state(:declarations, required: true)
            declarations.each do |name, decl|
              ENV.fetch("DEBUG_CASCADE", nil) && puts("  Processing declaration: #{name}")
              traverse_and_desugar(decl, node_index, errors)
            end

            ENV.fetch("DEBUG_CASCADE", nil) && puts("CascadeDesugarPass: Completed")
            state
          end

          private

          def traverse_and_desugar(node, node_index, errors)
            case node
            when Kumi::Syntax::CallExpression
              if node.fn_name == :cascade_and
                entry = node_index[node.object_id]

                case node.args.size
                when 0
                  # Empty cascade_and is invalid - requires at least one condition
                  puts("    CascadeDesugar call_id=#{node.object_id} args=0 status=ERROR") if ENV["DEBUG_CASCADE"]
                  errors << {
                    type: :semantic,
                    message: "cascade_and requires at least one condition",
                    location: node.loc || "unknown"
                  }
                  entry[:metadata][:invalid_cascade_and] = true if entry
                when 1
                  # Single-argument cascade_and is identity - just return the argument
                  puts("    CascadeDesugar call_id=#{node.object_id} args=1 desugar=identity skip_signature=true") if ENV["DEBUG_CASCADE"]
                  if entry
                    entry[:metadata][:desugar_to_identity] = true
                    entry[:metadata][:identity_arg] = node.args.first
                    entry[:metadata][:skip_signature] = true # Skip signature resolution for identity cases
                  end
                else
                  # Multi-argument cascade_and becomes boolean AND
                  if ENV["DEBUG_CASCADE"]
                    puts("    CascadeDesugar call_id=#{node.object_id} args=#{node.args.size} desugar=and qualified=core.and")
                  end
                  if entry
                    entry[:metadata][:original_fn_name] = :cascade_and
                    entry[:metadata][:desugared_to] = :and
                    entry[:metadata][:effective_fn_name] = :and
                    entry[:metadata][:canonical_name] = :and
                    entry[:metadata][:qualified_name] = "core.and"
                    entry[:metadata][:desugar_to_chained_and] = true
                  elsif ENV["DEBUG_CASCADE"]
                    puts("    Warning: cascade_and call_id=#{node.object_id} not found in node_index")
                  end
                end
              end
              # Traverse arguments
              node.args.each { |arg| traverse_and_desugar(arg, node_index, errors) }

            when Kumi::Syntax::CascadeExpression
              # Traverse cases
              node.cases.each { |case_expr| traverse_and_desugar(case_expr, node_index, errors) }

            when Kumi::Syntax::CaseExpression
              # Traverse condition and result
              traverse_and_desugar(node.condition, node_index, errors)
              traverse_and_desugar(node.result, node_index, errors)

            when Kumi::Syntax::ArrayExpression
              # Traverse elements
              node.elements.each { |elem| traverse_and_desugar(elem, node_index, errors) }

            when Kumi::Syntax::TraitDeclaration, Kumi::Syntax::ValueDeclaration
              # Traverse the expression
              traverse_and_desugar(node.expression, node_index, errors)

            when Kumi::Syntax::InputReference, Kumi::Syntax::InputElementReference,
                 Kumi::Syntax::DeclarationReference, Kumi::Syntax::Literal
              # Terminal nodes - nothing to traverse

            else
              # Unknown node type - might have nested expressions
              ENV.fetch("DEBUG_CASCADE", nil) && puts("    Unknown node type: #{node.class}")
            end
          end
        end
      end
    end
  end
end
