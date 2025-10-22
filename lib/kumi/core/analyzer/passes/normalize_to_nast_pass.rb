# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class NormalizeToNASTPass < PassBase
          NAST = Kumi::Core::NAST
          SELECT_ID = Kumi::RegistryV2::SELECT_ID

          def run(errors)
            decls = get_state(:declarations)
            order = get_state(:evaluation_order)
            @index_table = get_state(:index_table)
            @registry = get_state(:registry)

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

            when Kumi::Syntax::ImportCall
              normalize_import_call(node, errors)

            when Kumi::Syntax::CallExpression
              # Special handling section - very clear what's happening
              case node.fn_name
              when :cascade_and
                # Desugar cascade_and into chained binary core.and operations
                normalize_cascade_and(node.args, errors, node.loc)
              when :index
                normalize_index_ref(node, errors, node.loc)
              else
                normalize_call_expression(node, errors)
              end
            when Kumi::Syntax::CascadeExpression
              normalize_cascade(node, errors)
            when Kumi::Syntax::ArrayExpression
              args = node.elements.map { |a| normalize_expr(a, errors) }
              NAST::Tuple.new(args: args, loc: node.loc)
            when Kumi::Syntax::HashExpression
              pairs = node.pairs.map do |k, v|
                NAST::Pair.new(
                  key: k.value,
                  value: normalize_expr(v, errors)
                )
              end

              NAST::Hash.new(pairs:, loc: node.loc)
            else
              add_error(errors, node&.loc, "Unsupported AST node: #{node&.class}")
              NAST::Const.new(value: nil, loc: node&.loc)
            end
          end

          def normalize_call_expression(node, errors)
            begin
              fn_alias = FnAliases::MAP[node.fn_name] || node.fn_name

              # Try to get the function to check if it's expandable
              # For expandable functions, we need to resolve now
              # For regular functions, we defer resolution to NASTDimensionalAnalyzerPass
              func = begin
                @registry.function(fn_alias)
              rescue StandardError
                nil
              end
            rescue StandardError
              # puts "MISSING_FUNCTION: #{node.fn_name.inspect}"
              raise
            end

            if func && func.expand
              # 1. Normalize the arguments FIRST.
              normalized_args = node.args.map { |arg| normalize_expr(arg, errors) }

              # 2. Pass the normalized NAST arguments to the expander.
              # The expander will return a fully formed NAST node.
              MacroExpander.expand(func, normalized_args, node.loc, errors)
            else
              # Regular, non-expandable function call.
              # Keep the alias, don't resolve yet - let NASTDimensionalAnalyzerPass handle overload resolution
              args = node.args.map { |a| normalize_expr(a, errors) }
              NAST::Call.new(fn: fn_alias.to_sym, args: args, opts: node.opts, loc: node.loc)
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

          def normalize_index_ref(n, errors, loc)
            idx_name_n = normalize_expr(n.args.first, errors)

            debug "normalize_index_ref: idx_name_n=#{idx_name_n.inspect}, is Const? #{idx_name_n.is_a?(NAST::Const)}, value=#{idx_name_n.respond_to?(:value) ? idx_name_n.value.inspect : 'N/A'}"

            add_error(errors, loc, "index() needs a symbol") unless idx_name_n.is_a?(NAST::Const) && idx_name_n.value.is_a?(Symbol)
            idx_name = idx_name_n.value
            idx_meta = @index_table[idx_name]
            NAST::IndexRef.new(name: idx_name, input_fqn: idx_meta[:fqn])
          end

          def build_right_associative_and(normalized_args, loc)
            # Build: and(first, and(second, and(third, ...)))
            normalized_args.reverse.reduce do |right, left|
              NAST::Call.new(fn: :"core.and", args: [left, right], loc: loc)
            end
          end

          def normalize_import_call(node, errors)
            imported_schemas = get_state(:imported_schemas, required: false) || {}

            import_meta = imported_schemas[node.fn_name]
            unless import_meta
              add_error(errors, node.loc, "imported function `#{node.fn_name}` not found in imported_schemas")
              return NAST::Const.new(value: nil, loc: node.loc)
            end

            # Don't inline the source expression. Instead, create an NAST::ImportCall node
            # that represents a call to the compiled schema function.
            # The compiled schema handles its own internal dependencies.

            # Normalize the arguments (the values being passed)
            args = node.input_mapping.map do |param_name, caller_expr|
              normalize_expr(caller_expr, errors)
            end

            NAST::ImportCall.new(
              fn_name: node.fn_name,
              args: args,
              input_mapping_keys: node.input_mapping.keys,
              source_module: import_meta[:source_module],
              loc: node.loc
            )
          end
        end
      end
    end
  end
end
