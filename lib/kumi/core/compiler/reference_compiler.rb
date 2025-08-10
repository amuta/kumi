# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      module ReferenceCompiler
        private

        def compile_literal(expr)
          v = expr.value
          ->(_ctx) { v }
        end

        def compile_field_node(expr)
          compile_field(expr)
        end

        def compile_binding_node(expr)
          name = expr.name
          # Handle forward references in cycles by deferring binding lookup to runtime
          lambda do |ctx|
            fn = @bindings[name].last
            fn.call(ctx)
          end
        end

        def compile_field(node)
          name = node.name
          loc  = node.loc
          lambda do |ctx|
            return ctx[name] if ctx.respond_to?(:key?) && ctx.key?(name)

            raise Errors::RuntimeError,
                  "Key '#{name}' not found at #{loc}. Available: #{ctx.respond_to?(:keys) ? ctx.keys.join(', ') : 'N/A'}"
          end
        end

        def compile_declaration(decl)
          @current_declaration = decl.name
          kind = decl.is_a?(Kumi::Syntax::TraitDeclaration) ? :trait : :attr
          fn = compile_expr(decl.expression)
          @bindings[decl.name] = [kind, fn]
          @current_declaration = nil
        end
      end
    end
  end
end
