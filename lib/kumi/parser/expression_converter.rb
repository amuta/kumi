# frozen_string_literal: true

module Kumi
  module Parser
    class ExpressionConverter
      include Syntax
      include ErrorReporting

      def initialize(context)
        @context = context
      end

      def ensure_syntax(obj)
        case obj
        when Integer, String, TrueClass, FalseClass, Float, Regexp, Symbol
          Literal.new(obj)
        when Array
          ListExpression.new(obj.map { |e| ensure_syntax(e) })
        when Syntax::Node
          obj
        else
          handle_complex_object(obj)
        end
      end

      def ref(name)
        Binding.new(name, loc: @context.current_location)
      end

      def literal(value)
        Literal.new(value, loc: @context.current_location)
      end

      def fn(fn_name, *args)
        expr_args = args.map { |a| ensure_syntax(a) }
        CallExpression.new(fn_name, expr_args, loc: @context.current_location)
      end

      def input
        InputProxy.new(@context)
      end

      def raise_error(message, location)
        raise_syntax_error(message, location: location)
      end

      private

      def handle_complex_object(obj)
        if obj.class.instance_methods.include?(:to_ast_node)
          obj.to_ast_node
        else
          raise_syntax_error("Invalid expression: #{obj.inspect}", location: @context.current_location)
        end
      end
    end
  end
end
