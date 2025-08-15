module Kumi
  module Core
    module Analyzer
      module Passes
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
                # Find this node in the index and mark for desugaring
                entry = node_index[node.object_id]
                if entry
                  ENV["DEBUG_CASCADE"] && puts("    Marking cascade_and for desugaring to and")
                  entry[:metadata][:original_fn_name] = :cascade_and
                  entry[:metadata][:desugared_to] = :and
                  entry[:metadata][:effective_fn_name] = :and
                  entry[:metadata][:canonical_name] = :and
                  entry[:metadata][:qualified_name] = "core.and"
                else
                  ENV["DEBUG_CASCADE"] && puts("    Warning: cascade_and node not found in index")
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