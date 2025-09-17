# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class NormalizeToNASTPass < PassBase
          NAST = Kumi::Core::NAST
          SELECT_ID = Kumi::RegistryV2::SELECT_ID

          def run(errors)
            decls = get_state(:declarations, required: true)
            order = get_state(:evaluation_order, required: true)
            @registry = get_state(:registry, required: true)

            nast_decls = {}
            order.each do |name|
              ast = decls[name] or next
              body = normalize_expr(ast.expression, errors)
              nast_decls[name] = NAST::Declaration.new(name: name, body: body, loc: ast.loc, meta: { kind: ast.kind })
            end

            nast = NAST::Module.new(decls: nast_decls)
            debug "NAST decl keys: #{nast.decls.keys.inspect}"
            state.with(:nast_module, nast)
          end

          private

          def normalize_expr(node, errors)
            case node
            when Kumi::Syntax::Literal
              NAST::Const.new(value: node.value, loc: node.loc)

            when Kumi::Syntax::InputReference
              NAST::InputRef.new(path: [node.name], loc: node.loc)

            when Kumi::Syntax::InputElementReference
              NAST::InputRef.new(path: node.path, loc: node.loc)

            when Kumi::Syntax::DeclarationReference
              NAST::Ref.new(name: node.name, loc: node.loc)

            when Kumi::Syntax::CallExpression
              # Special handling section - very clear what's happening
              case node.fn_name
              when :cascade_and
                # Desugar cascade_and into chained binary core.and operations
                normalize_cascade_and(node.args, errors, node.loc)
              else
                normalize_call_expression(node, errors)
              end
            when Kumi::Syntax::CascadeExpression
              normalize_cascade(node, errors)
            when Kumi::Syntax::ArrayExpression
              args = node.elements.map { |a| normalize_expr(a, errors) }
              NAST::Tuple.new(args: args, loc: node.loc)
            else
              add_error(errors, node&.loc, "Unsupported AST node: #{node&.class}")
              NAST::Const.new(value: nil, loc: node&.loc)
            end
          end

          def normalize_call_expression(node, errors)
            begin
              func = @registry.function(node.fn_name)
            rescue StandardError
              puts "MISSING_FUNCTION: #{node.fn_name.inspect}"
              raise
            end

            if func.expand
              # 1. Normalize the arguments FIRST.
              normalized_args = node.args.map { |arg| normalize_expr(arg, errors) }

              # 2. Pass the normalized NAST arguments to the expander.
              # The expander will return a fully formed NAST node.
              MacroExpander.expand(func, normalized_args, node.loc, errors)
            else
              # Regular, non-expandable function call.
              args = node.args.map { |a| normalize_expr(a, errors) }
              NAST::Call.new(fn: func.id.to_sym, args: args, loc: node.loc)
            end
          end

          def normalize_cascade(cas, errors)
            # Find the base case (condition = true)
            base = cas.cases.find do |c|
              c.condition.is_a?(Kumi::Syntax::Literal) && c.condition.value == true
            end
            default_expr = base ? base.result : Kumi::Syntax::Literal.new(nil, loc: cas.loc)
            branches = cas.cases.reject { |c| c.equal?(base) }

            # Build nested if expression (reverse order)
            else_n = normalize_expr(default_expr, errors)
            branches.reverse_each do |br|
              cond = normalize_expr(br.condition, errors)
              val = normalize_expr(br.result, errors)
              else_n = NAST::Call.new(fn: SELECT_ID, args: [cond, val, else_n], loc: br.condition.loc)
            end
            else_n
          end

          def normalize_cascade_and(args, errors, loc)
            # Desugar cascade_and into chained binary core.and operations
            case args.size
            when 0
              # Edge case: no arguments - should probably be an error
              add_error(errors, loc, "cascade_and requires at least one argument")
              NAST::Const.new(value: true, loc: loc)
            when 1
              # Single argument: no 'and' needed, just normalize the argument
              normalize_expr(args[0], errors)
            else
              # Multiple arguments: create right-associative binary tree
              # cascade_and(a, b, c) -> and(a, and(b, c))
              normalized_args = args.map { |arg| normalize_expr(arg, errors) }
              build_right_associative_and(normalized_args, loc)
            end
          end

          def build_right_associative_and(normalized_args, loc)
            # Build: and(first, and(second, and(third, ...)))
            normalized_args.reverse.reduce do |right, left|
              NAST::Call.new(fn: :"core.and", args: [left, right], loc: loc)
            end
          end
        end
      end
    end
  end
end
