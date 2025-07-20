# frozen_string_literal: true

require_relative "input_dsl_proxy"
require_relative "input_proxy"

module Kumi
  module Parser
    class DslBuilderContext
      attr_accessor :last_loc
      attr_reader :inputs, :attributes, :traits, :functions

      include Syntax::Declarations
      include Syntax::Expressions
      include Syntax::TerminalExpressions

      def initialize
        @inputs     = []
        @attributes = []
        @traits     = []
        @functions  = []
      end

      def value(name, expr = nil, &blk)
        loc = current_location
        validate_name(name, :value, loc)

        has_expr = !expr.nil?
        has_block = block_given?

        if has_expr && has_block
          raise_error("value '#{name}' cannot be called with both an expression and a block", loc)
        elsif !has_expr && !has_block
          raise_error("value '#{name}' requires an expression or a block.", loc)
        end

        expr =
          if blk
            build_cascade(loc, &blk)
          else
            ensure_syntax(expr, loc)
          end

        @attributes << Attribute.new(name, expr, loc: loc)
      end

      def trait(name, lhs, operator, *rhs)
        unless rhs.size.positive?
          raise_error("trait '#{name}' requires exactly 3 arguments: lhs, operator, and rhs",
                      current_location)
        end
        loc = current_location
        validate_name(name, :trait, loc)
        raise_error("expects a symbol for an operator, got #{operator.class}", loc) unless operator.is_a?(Symbol)

        raise_error("unsupported operator `#{operator}`", loc) unless FunctionRegistry.operator?(operator)

        rhs_expr = rhs.map { |r| ensure_syntax(r, loc) }
        expr = CallExpression.new(operator, [ensure_syntax(lhs, loc)] + rhs_expr, loc: loc)
        @traits << Trait.new(name, expr, loc: loc)
      end

      def input(&blk)
        return InputProxy.new(self) unless block_given?

        raise_error("input block already defined", current_location) if @_input_block
        @_input_block = true

        proxy = InputDslProxy.new(self)
        proxy.instance_eval(&blk)
      end

      def ref(name)
        Binding.new(name, loc: current_location)
      end

      def literal(value)
        Literal.new(value, loc: current_location)
      end

      def fn(fn_name, *args)
        loc = current_location
        expr_args = args.map { |a| ensure_syntax(a, loc) }
        CallExpression.new(fn_name, expr_args, loc: loc)
      end

      def current_location
        # if proxy set @last_loc, use it; otherwise fallback as before
        return last_loc if last_loc

        fallback = caller_locations.find(&:absolute_path)
        Syntax::Location.new(file: fallback.path, line: fallback.lineno, column: 0)
      end

      def raise_error(message, location)
        raise Errors::SyntaxError, "at #{location.file}:#{location.line}: #{message}"
      end

      private

      def validate_name(name, type, location)
        return if name.is_a?(Symbol)

        raise_error("The name for '#{type}' must be a Symbol, got #{name.class}", location)
      end

      def ensure_syntax(obj, location)
        case obj
        when Integer, String, Symbol, TrueClass, FalseClass, Float, Regexp then literal(obj)
        when Array then ListExpression.new(obj.map { |e| ensure_syntax(e, location) })
        when Syntax::Node then obj
        else
          raise_error("Invalid expression: #{obj.inspect}", location)
        end
      end

      # def current_location
      #   Kumi.current_location
      # end

      def build_cascade(loc, &blk)
        cascade_builder = DslCascadeBuilder.new(self, loc)
        cascade_builder.instance_eval(&blk)

        CascadeExpression.new(cascade_builder.cases, loc: loc)
      end

      def method_missing(method_name, *args, &block)
        if args.empty? && !block_given?
          Binding.new(method_name, loc: current_location)
        else
          super
        end
      end

      def respond_to_missing?(_method_name, _include_private = false)
        true
      end
    end
  end
end
