# frozen_string_literal: true

require_relative "input_dsl_proxy"
require_relative "input_proxy"

module Kumi
  module Parser
    class DslBuilderContext
      attr_accessor :last_loc
      attr_reader :inputs, :attributes, :traits, :functions

      include Syntax

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

      def trait(*args, **kwargs)
        # Keyword syntax: trait old: (input.age >= 50), adult: (input.age >= 18)
        unless kwargs.empty?
          kwargs.each do |name, expression|
            loc = current_location
            validate_name(name, :trait, loc)
            expr = ensure_syntax(expression, loc)
            @traits << Trait.new(name, expr, loc: loc)
          end
          return
        end

        # Handle positional arguments
        case args.size
        when 2
          # NEW CLEAN SYNTAX: trait :name, (expression)
          name, expression = args
          loc = current_location
          validate_name(name, :trait, loc)
          expr = ensure_syntax(expression, loc)
          @traits << Trait.new(name, expr, loc: loc)
        when 4
          # OLD DEPRECATED SYNTAX: trait(:name, lhs, operator, rhs)
          warn "DEPRECATION: trait(:name, lhs, operator, rhs) syntax is deprecated. Use: trait :name, (lhs operator rhs)"
          name, lhs, operator, rhs = args
          loc = current_location
          validate_name(name, :trait, loc)
          raise_error("expects a symbol for an operator, got #{operator.class}", loc) unless operator.is_a?(Symbol)

          raise_error("unsupported operator `#{operator}`", loc) unless FunctionRegistry.operator?(operator)

          rhs_expr = ensure_syntax(rhs, loc)
          expr = CallExpression.new(operator, [ensure_syntax(lhs, loc), rhs_expr], loc: loc)
          @traits << Trait.new(name, expr, loc: loc)
        else
          # Multiple RHS args (old deprecated syntax): trait :name, lhs, operator, *rhs
          warn "DEPRECATION: trait(:name, lhs, operator, *rhs) syntax is deprecated. Use: trait :name, (lhs operator rhs)"
          name, lhs, operator, *rhs = args
          raise_error("trait '#{name}' requires exactly 3 arguments: lhs, operator, and rhs", current_location) unless rhs.size.positive?
          loc = current_location
          validate_name(name, :trait, loc)
          raise_error("expects a symbol for an operator, got #{operator.class}", loc) unless operator.is_a?(Symbol)

          raise_error("unsupported operator `#{operator}`", loc) unless FunctionRegistry.operator?(operator)

          rhs_expr = rhs.map { |r| ensure_syntax(r, loc) }
          expr = CallExpression.new(operator, [ensure_syntax(lhs, loc)] + rhs_expr, loc: loc)
          @traits << Trait.new(name, expr, loc: loc)
        end
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

      def validate_name(name, type, location)
        return if name.is_a?(Symbol)

        raise_error("The name for '#{type}' must be a Symbol, got #{name.class}", location)
      end

      def method_missing(method_name, *args, &block)
        if args.empty? && !block_given?
          # Return a composable trait reference instead of a plain Binding
          ComposableTraitRef.new(method_name, self)
        else
          super
        end
      end

      def respond_to_missing?(_method_name, _include_private = false)
        true
      end

      # Composable wrapper for trait references that supports & operator
      class ComposableTraitRef
        def initialize(name, context)
          @name = name
          @context = context
        end

        def &(other)
          # Create an AND expression between this trait and another
          left = @context.ref(@name)
          right = case other
                  when ComposableTraitRef
                    @context.ref(other.name)
                  when Syntax::Node
                    other
                  else
                    @context.ensure_syntax(other, @context.current_location)
                  end
          Syntax::Expressions::CallExpression.new(:and, [left, right], loc: @context.current_location)
        end

        def to_ast_node
          @context.ref(@name)
        end

        protected

        attr_reader :name
      end

      def ensure_syntax(obj, location)
        case obj
        when Integer, String, TrueClass, FalseClass, Float, Regexp then literal(obj)
        when Symbol then literal(obj)
        when Array then ListExpression.new(obj.map { |e| ensure_syntax(e, location) })
        when Syntax::Node then obj
        when ComposableTraitRef then obj.to_ast_node
        else
          # Check if it's an ExpressionWrapper or similar (without calling respond_to_missing?)
          if obj.class.instance_methods.include?(:to_ast_node)
            obj.to_ast_node
          else
            raise_error("Invalid expression: #{obj.inspect}", location)
          end
        end
      end

      private

      # def current_location
      #   Kumi.current_location
      # end

      def build_cascade(loc, &blk)
        cascade_builder = DslCascadeBuilder.new(self, loc)
        cascade_builder.instance_eval(&blk)

        CascadeExpression.new(cascade_builder.cases, loc: loc)
      end
    end
  end
end
