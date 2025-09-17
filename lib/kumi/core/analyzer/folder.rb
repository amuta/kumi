# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      class Folder
        def initialize(pass, nast_module, order, registry)
          @nast_module = nast_module
          @order = order
          @registry = registry
          @pass = pass
          @known_constants = {}
          @changed = false
        end

        def debug(msg)
          @pass.method(:debug).call(msg)
        end

        def fold
          folded_decls = {}
          @order.each do |decl_name|
            decl = @nast_module.decls[decl_name]
            next unless decl

            folded_decls[decl_name] = fold_declaration(decl)
          end

          [NAST::Module.new(decls: folded_decls), @changed]
        end

        def fold_declaration(decl)
          debug "[FOLD]   Folding declaration :#{decl.name}"
          new_body = fold_node(decl.body)
          @changed ||= !new_body.equal?(decl.body)

          # *** FIX ***: A node is constant if it's a Const OR a Tuple of only Consts.
          is_constant = new_body.is_a?(NAST::Const) ||
                        (new_body.is_a?(NAST::Tuple) && new_body.args.all? { |arg| arg.is_a?(NAST::Const) })

          if is_constant
            @known_constants[decl.name] = new_body
            debug "[FOLD]     - Identified :#{decl.name} as a constant value."
          end

          NAST::Declaration.new(name: decl.name, body: new_body, loc: decl.loc, meta: decl.meta)
        end

        def fold_node(node)
          case node
          when NAST::Call
            fold_call(node)
          when NAST::Ref
            resolved_node = @known_constants.fetch(node.name, node)
            unless resolved_node.equal?(node)
              debug "[FOLD]     - Propagating constant for ref :#{node.name}"
              @changed = true
            end
            resolved_node
          when NAST::Tuple
            new_args = node.args.map { |arg| fold_node(arg) }
            new_args.map(&:object_id) == node.args.map(&:object_id) ? node : NAST::Tuple.new(args: new_args, loc: node.loc)
          else
            node
          end
        end

        def fold_call(node)
          folded_args = node.args.map { |arg| fold_node(arg) }
          folded_call = if folded_args.map(&:object_id) == node.args.map(&:object_id)
                          node
                        else
                          NAST::Call.new(fn: node.fn,
                                         args: folded_args, loc: node.loc)
                        end

          debug "[FOLD]     - Attempting to evaluate call to :#{folded_call.fn}"
          evaluated_value = ConstantEvaluator.evaluate(folded_call, @registry, @known_constants)

          if evaluated_value.nil?
            debug "[FOLD]       - Could not evaluate. Keeping call."
            folded_call
          else
            debug "[FOLD]       - SUCCESS! Folded call to :#{folded_call.fn} -> #{evaluated_value.inspect}"
            @changed = true
            NAST::Const.new(value: evaluated_value, loc: node.loc)
          end
        end
      end
    end
  end
end
