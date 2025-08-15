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
            ENV["DEBUG_CASCADE"] && puts("CascadeDesugarPass: Starting desugar pass")
            
            node_index = get_state(:node_index, required: true)
            
            # Traverse all declarations and their nested expressions
            declarations = get_state(:declarations, required: true)
            declarations.each do |name, decl|
              ENV["DEBUG_CASCADE"] && puts("  Processing declaration: #{name}")
              traverse_and_desugar(decl, node_index)
            end
            
            ENV["DEBUG_CASCADE"] && puts("CascadeDesugarPass: Completed")
            state
          end

          private

          def traverse_and_desugar(node, node_index)
            case node
            when Kumi::Syntax::CallExpression
              if node.fn_name == :cascade_and
                entry = node_index[node.object_id]
                
                case node.args.size
                when 0
                  # Empty cascade_and is invalid - requires at least one condition
                  ENV["DEBUG_CASCADE"] && puts("    ERROR: cascade_and() requires at least one condition")
                  errors << {
                    type: :semantic,
                    message: "cascade_and requires at least one condition",
                    location: node.loc || "unknown"
                  }
                  if entry
                    entry[:metadata][:invalid_cascade_and] = true
                  end
                when 1
                  # Single-argument cascade_and is identity - just return the argument
                  ENV["DEBUG_CASCADE"] && puts("    Desugaring cascade_and(1 arg) to identity")
                  if entry
                    entry[:metadata][:desugar_to_identity] = true
                    entry[:metadata][:identity_arg] = node.args.first
                  end
                else
                  # Multi-argument cascade_and becomes boolean AND
                  ENV["DEBUG_CASCADE"] && puts("    Marking cascade_and(#{node.args.size} args) for desugaring to and")
                  if entry
                    entry[:metadata][:original_fn_name] = :cascade_and
                    entry[:metadata][:desugared_to] = :and
                    entry[:metadata][:effective_fn_name] = :and
                    entry[:metadata][:canonical_name] = :and
                    entry[:metadata][:qualified_name] = "core.and"
                  else
                    ENV["DEBUG_CASCADE"] && puts("    Warning: cascade_and node not found in index")
                  end
                end
              end
              # Traverse arguments
              node.args.each { |arg| traverse_and_desugar(arg, node_index) }
              
            when Kumi::Syntax::CascadeExpression
              # Traverse cases
              node.cases.each { |case_expr| traverse_and_desugar(case_expr, node_index) }
              
            when Kumi::Syntax::CaseExpression
              # Traverse condition and result
              traverse_and_desugar(node.condition, node_index)
              traverse_and_desugar(node.result, node_index)
              
            when Kumi::Syntax::ArrayExpression
              # Traverse elements
              node.elements.each { |elem| traverse_and_desugar(elem, node_index) }
              
            when Kumi::Syntax::TraitDeclaration, Kumi::Syntax::ValueDeclaration
              # Traverse the expression
              traverse_and_desugar(node.expression, node_index)
              
            when Kumi::Syntax::InputReference, Kumi::Syntax::InputElementReference, 
                 Kumi::Syntax::DeclarationReference, Kumi::Syntax::Literal
              # Terminal nodes - nothing to traverse
              
            else
              # Unknown node type - might have nested expressions
              ENV["DEBUG_CASCADE"] && puts("    Unknown node type: #{node.class}")
            end
          end
        end
      end
    end
  end
end