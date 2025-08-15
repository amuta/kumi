# frozen_string_literal: true

module Kumi
  module Core
    module RubyParser
      class SchemaBuilder
        include GuardRails
        include Syntax
        include ErrorReporting

        DSL_METHODS = %i[value trait input ref literal fn].freeze

        def initialize(context)
          @context = context
        end

        def value(name = nil, expr = nil, &blk)
          update_location
          validate_value_args(name, expr, blk)

          expression = blk ? build_cascade(&blk) : ensure_syntax(expr)
          @context.values << Kumi::Syntax::ValueDeclaration.new(name, expression, loc: @context.current_location)
        end

        def trait(*args, **kwargs)
          update_location
          raise_syntax_error("keyword trait syntax not supported", location: @context.current_location) unless kwargs.empty?
          build_positional_trait(args)
        end

        def input(&blk)
          return InputProxy.new(@context) unless block_given?

          raise_syntax_error("input block already defined", location: @context.current_location) if @context.input_block_defined?
          @context.mark_input_block_defined!

          update_location
          input_builder = InputBuilder.new(@context)
          input_builder.instance_eval(&blk)
        end

        def ref(name)
          update_location
          Kumi::Syntax::DeclarationReference.new(name, loc: @context.current_location)
        end

        def literal(value)
          update_location
          Kumi::Syntax::Literal.new(value, loc: @context.current_location)
        end

        def fn(fn_name, *args)
          update_location
          expr_args = args.map { |a| ensure_syntax(a) }
          Kumi::Syntax::CallExpression.new(fn_name, expr_args, loc: @context.current_location)
        end

        def method_missing(method_name, *args, &block)
          if args.empty? && !block_given?
            update_location
            # Create proxy for declaration references (traits/values)
            DeclarationReferenceProxy.new(method_name, @context)
          else
            super
          end
        end

        def respond_to_missing?(_method_name, _include_private = false)
          true
        end

        private

        def update_location
          # Use caller_locations(2, 1) to skip the DSL method and get the actual user code location
          # Stack: [0] update_location, [1] DSL method (value/trait/etc), [2] user's DSL code
          caller_location = caller_locations(2, 1).first

          @context.current_location = Location.new(
            file: caller_location.path,
            line: caller_location.lineno,
            column: 0
          )
        end

        def validate_value_args(name, expr, blk)
          raise_syntax_error("value requires a name as first argument", location: @context.current_location) if name.nil?
          unless name.is_a?(Symbol)
            raise_syntax_error("The name for 'value' must be a Symbol, got #{name.class}",
                               location: @context.current_location)
          end

          has_expr = !expr.is_a?(NilClass)
          has_block = blk

          if has_expr && has_block
            raise_syntax_error("value '#{name}' cannot be called with both an expression and a block", location: @context.current_location)
          elsif !has_expr && !has_block
            raise_syntax_error("value '#{name}' requires an expression or a block", location: @context.current_location)
          end
        end

        def build_positional_trait(args)
          case args.size
          when 0
            raise_syntax_error("trait requires a name and expression", location: @context.current_location)
          when 1
            name = args.first
            raise_syntax_error("trait '#{name}' requires an expression", location: @context.current_location)
          when 2
            name, expression = args
            validate_trait_name(name)
            expr = ensure_syntax(expression)
            @context.traits << Kumi::Syntax::TraitDeclaration.new(name, expr, loc: @context.current_location)
          else
            handle_deprecated_trait_syntax(args)
          end
        end

        def handle_deprecated_trait_syntax(args)
          if args.size == 3
            name, = args
            raise_syntax_error("trait '#{name}' requires exactly 3 arguments: lhs, operator, and rhs", location: @context.current_location)
          end

          # warn "DEPRECATION: trait(:name, lhs, operator, rhs) syntax is deprecated. Use: trait :name, (lhs operator rhs)"

          if args.size == 4
            name, lhs, operator, rhs = args
            build_deprecated_trait(name, lhs, operator, [rhs])
          else
            name, lhs, operator, *rhs = args
            build_deprecated_trait(name, lhs, operator, rhs)
          end
        end

        def build_deprecated_trait(name, lhs, operator, rhs)
          validate_trait_name(name)
          validate_operator(operator)

          # Normalize operator to canonical basename
          normalized_operator = Kumi::Core::Naming::BasenameNormalizer.normalize(operator)
          rhs_exprs = rhs.map { |r| ensure_syntax(r) }
          expr = Kumi::Syntax::CallExpression.new(normalized_operator, [ensure_syntax(lhs)] + rhs_exprs, loc: @context.current_location)
          @context.traits << Kumi::Syntax::TraitDeclaration.new(name, expr, loc: @context.current_location)
        end

        def validate_trait_name(name)
          return if name.is_a?(Symbol)

          raise_syntax_error("The name for 'trait' must be a Symbol, got #{name.class}", location: @context.current_location)
        end

        def validate_operator(operator)
          unless operator.is_a?(Symbol)
            raise_syntax_error("expects a symbol for an operator, got #{operator.class}", location: @context.current_location)
          end

          return if Kumi::Registry.operator?(operator)

          raise_syntax_error("unsupported operator `#{operator}`", location: @context.current_location)
        end

        def build_cascade(&blk)
          expression_converter = ExpressionConverter.new(@context)
          cascade_builder = DslCascadeBuilder.new(expression_converter, @context.current_location)
          cascade_builder.instance_eval(&blk)
          Kumi::Syntax::CascadeExpression.new(cascade_builder.cases, loc: @context.current_location)
        end

        def ensure_syntax(obj)
          ExpressionConverter.new(@context).ensure_syntax(obj)
        end
      end
    end
  end
end
