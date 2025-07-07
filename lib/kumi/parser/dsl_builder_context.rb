# frozen_string_literal: true

module Kumi
  module Parser
    class DslBuilderContext
      attr_accessor :last_loc
      attr_reader :attributes, :traits, :functions

      include Syntax::Declarations
      include Syntax::Expressions
      include Syntax::TerminalExpressions

      def initialize
        @attributes = []
        @traits     = []
        @functions  = []
      end

      def attribute(name, expr = nil, &blk)
        loc = current_location
        validate_name(name, :attribute, loc)

        has_expr = !expr.nil?
        has_block = block_given?

        if has_expr && has_block
          raise_error("attribute '#{name}' cannot be called with both an expression and a block", loc)
        elsif !has_expr && !has_block
          raise_error("attribute '#{name}' requires an expression or a block.", loc)
        end

        expr =
          if blk
            build_cascade(loc, &blk)
          else
            ensure_syntax(expr, loc)
          end

        binding.pry if expr.nil?
        @attributes << Attribute.new(name, expr, loc: loc)
      end

      def trait(name, *expression)
        unless expression.size == 3
          raise_error("trait '#{name}' requires exactly 3 arguments: lhs, operator, and rhs",
                      current_location)
        end

        lhs, operator, rhs = expression

        loc = current_location
        validate_name(name, :trait, loc)
        raise_error("expects a symbol for an operator, got #{operator.class}", loc) unless operator.is_a?(Symbol)

        raise_error("unsupported operator `#{operator}`", loc) unless MethodCallRegistry.operator?(operator)

        expr = CallExpression.new(operator, [ensure_syntax(lhs, loc), ensure_syntax(rhs, loc)], loc: loc)
        @traits << Trait.new(name, expr, loc: loc)
      end

      def key(name)
        Field.new(name, loc: current_location)
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

      private

      def validate_name(name, type, location)
        return if name.is_a?(Symbol)

        raise_error("The name for '#{type}' must be a Symbol, got #{name.class}", location)
      end

      def ensure_syntax(obj, location)
        case obj
        when Integer, String, Symbol, TrueClass, FalseClass then literal(obj)
        when Array then ListExpression.new(obj.map { |e| ensure_syntax(e, location) })
        when Syntax::Node then obj
        else
          raise_error("Invalid expression: #{obj.inspect}", location)
        end
      end

      # def current_location
      #   Kumi.current_location
      # end

      def raise_error(message, location)
        raise Errors::SyntaxError, "at #{location.file}:#{location.line}: #{message}"
      end

      def build_cascade(loc, &blk)
        cascade_builder = DslCascadeBuilder.new(self, loc)
        cascade_builder.instance_eval(&blk)

        CascadeExpression.new(cascade_builder.cases, loc: loc)
      end

      def current_location
        # if proxy set @last_loc, use it; otherwise fallback as before
        return last_loc if last_loc

        fallback = caller_locations.find(&:absolute_path)
        Syntax::Location.new(file: fallback.path, line: fallback.lineno, column: 0)
      end
    end
  end
end
