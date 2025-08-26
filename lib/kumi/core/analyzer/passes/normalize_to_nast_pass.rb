# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class NormalizeToNASTPass < PassBase
          FNAME_ARRAY = :'core.array'
          FNAME_SELECT = :'core.select'

          def run(errors)
            decls = get_state(:declarations, required: true)
            order = get_state(:evaluation_order, required: true)

            nast_decls = {}
            order.each do |name|
              ast = decls[name] or next
              kind = ast.is_a?(Kumi::Syntax::TraitDeclaration) ? :trait : :value
              body = normalize_expr(ast.expression, errors)
              nast_decls[name] = Kumi::Core::NAST::Decl.new(name: name, kind: kind, body: body, loc: ast.loc)
            end

            nast = Kumi::Core::NAST::Module.new(decls: nast_decls)
            state.with(:nast_module, nast)
          end

          private

          def normalize_expr(node, errors)
            case node
            when Kumi::Syntax::Literal
              Kumi::Core::NAST::Const.new(value: node.value, loc: node.loc)

            when Kumi::Syntax::InputReference
              Kumi::Core::NAST::InputRef.new(path: [node.name], loc: node.loc)

            when Kumi::Syntax::InputElementReference
              Kumi::Core::NAST::InputRef.new(path: node.path, loc: node.loc)

            when Kumi::Syntax::DeclarationReference
              Kumi::Core::NAST::Ref.new(name: node.name, loc: node.loc)

            when Kumi::Syntax::CallExpression
              fn = Kumi::Core::Analyzer::FnAliases.canonical(node.fn_name)
              args = node.args.map { |a| normalize_expr(a, errors) }
              Kumi::Core::NAST::Call.new(fn: fn, args: args, loc: node.loc)
            when Kumi::Syntax::CascadeExpression
              normalize_cascade(node, errors)
            when Kumi::Syntax::ArrayExpression
              args = node.elements.map { |a| normalize_expr(a, errors) }
              Kumi::Core::NAST::Call.new(fn: FNAME_ARRAY, args: args, loc: node.loc)
            else
              add_error(errors, node&.loc, "Unsupported AST node: #{node&.class}")
              Kumi::Core::NAST::Const.new(value: nil, loc: node&.loc)
            end
          end

          def normalize_cascade(cas, errors)
            # Find the base case (condition = true)
            base = cas.cases.find { |c|
              c.condition.is_a?(Kumi::Syntax::Literal) && c.condition.value == true
            }
            default_expr = base ? base.result : Kumi::Syntax::Literal.new(nil, loc: cas.loc)
            branches = cas.cases.reject { |c| c.equal?(base) }

            # Build nested if expression (reverse order)
            else_n = normalize_expr(default_expr, errors)
            branches.reverse_each do |br|
              cond = normalize_expr(br.condition, errors)
              val = normalize_expr(br.result, errors)
              else_n = Kumi::Core::NAST::Call.new(fn: FNAME_SELECT, args: [cond, val, else_n], loc: br.condition.loc)
            end
            else_n
          end
        end
      end
    end
  end
end