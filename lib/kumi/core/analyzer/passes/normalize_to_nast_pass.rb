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

            nast_decls = {}
            order.each do |name|
              ast = decls[name] or next
              body = normalize_expr(ast.expression, errors)
              nast_decls[name] = NAST::Declaration.new(name: name, body: body, loc: ast.loc, meta: {kind: ast.kind})
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
              when :sum_if, :count_if, :max_if, :avg_if
                # Macro expansion: agg_if(values, condition) → agg(select(condition, values, neutral))
                normalize_agg_if_macro(node, errors)
              else
                # Regular function call
                fn = Kumi::Core::Analyzer::FnAliases.canonical(node.fn_name)
                args = node.args.map { |a| normalize_expr(a, errors) }
                NAST::Call.new(fn: fn, args: args, loc: node.loc)
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
              NAST::Call.new(fn: :'core.and', args: [left, right], loc: loc)
            end
          end

          def normalize_agg_if_macro(node, errors)
            # Very clear: sum_if(values, condition) → sum(select(condition, values, neutral))
            base_fn = node.fn_name.to_s.sub('_if', '')  # sum_if → sum
            
            if node.args.size != 2
              add_error(errors, node.loc, "#{node.fn_name} expects exactly 2 arguments: values and condition")
              return NAST::Const.new(value: nil, loc: node.loc)
            end
            
            values, condition = node.args
            neutral = neutral_value_for(base_fn)
            
            # Expand to: sum(select(condition, values, neutral))
            select_call = NAST::Call.new(
              fn: SELECT_ID,
              args: [normalize_expr(condition, errors), 
                     normalize_expr(values, errors),
                     NAST::Const.new(value: neutral, loc: node.loc)],
              loc: node.loc
            )
            
            NAST::Call.new(
              fn: "agg.#{base_fn}".to_sym,
              args: [select_call],
              loc: node.loc
            )
          end

          def neutral_value_for(base_fn)
            # TODO: this should be a policy probably, and this is not the identity.
            #        also it should follow the type, this will break for most things 
            #        not ruby
            # Return appropriate neutral values for different aggregation functions
            case base_fn
            when 'sum'   then 0
            when 'count' then 0  # For count, we'll filter out rather than use neutral
            when 'max'   then Float::INFINITY * -1  # -∞
            when 'avg'   then 0  # For average, this is more complex but start with 0
            else
              0  # Default neutral value
            end
          end
        end
      end
    end
  end
end