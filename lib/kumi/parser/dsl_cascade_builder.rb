# frozen_string_literal: true

module Kumi
  module Parser
    class DslCascadeBuilder
      include Syntax

      attr_reader :cases

      def initialize(context, loc)
        @context = context
        @cases   = []
        @loc = loc
      end

      def on(*args)
        on_loc = current_location
        validate_on_args(args, "on", on_loc)

        trait_names = args[0..-2]
        expr = args.last

        trait_bindings = convert_trait_names_to_bindings(trait_names, on_loc)
        condition = create_fn(:all?, trait_bindings)
        result = ensure_syntax(expr)
        add_case(condition, result)
      end

      def on_any(*args)
        on_loc = current_location
        validate_on_args(args, "on_any", on_loc)

        trait_names = args[0..-2]
        expr = args.last

        trait_bindings = convert_trait_names_to_bindings(trait_names, on_loc)
        condition = create_fn(:any?, trait_bindings)
        result = ensure_syntax(expr)
        add_case(condition, result)
      end

      def on_none(*args)
        on_loc = current_location
        validate_on_args(args, "on_none", on_loc)

        trait_names = args[0..-2]
        expr = args.last

        trait_bindings = convert_trait_names_to_bindings(trait_names, on_loc)
        condition = create_fn(:none?, trait_bindings)
        result = ensure_syntax(expr)
        add_case(condition, result)
      end

      def base(expr)
        result = ensure_syntax(expr)
        add_case(create_literal(true), result)
      end

      def method_missing(method_name, *args, &block)
        return super if !args.empty? || block_given?

        # Allow direct trait references in cascade conditions
        create_binding(method_name, @loc)
      end

      def respond_to_missing?(_method_name, _include_private = false)
        true
      end

      private

      def current_location
        caller_info = caller_locations(1, 1).first
        Location.new(file: caller_info.path, line: caller_info.lineno, column: 0)
      end

      def validate_on_args(args, method_name, location)
        raise_error("cascade '#{method_name}' requires at least one trait name", location) if args.empty?

        return unless args.size == 1

        raise_error("cascade '#{method_name}' requires an expression as the last argument", location)
      end

      def convert_trait_names_to_bindings(trait_names, location)
        trait_names.map do |name|
          case name
          when Symbol
            create_binding(name, location)
          when Binding
            name  # Already a binding from method_missing
          else
            raise_error("trait reference must be a symbol or bare identifier, got #{name.class}", location)
          end
        end
      end

      def add_case(condition, result)
        @cases << WhenCaseExpression.new(condition, result)
      end

      def ref(name)
        @context.ref(name)
      end

      def fn(name, *args)
        @context.fn(name, *args)
      end

      def create_literal(value)
        @context.literal(value)
      end

      def create_fn(name, args)
        @context.fn(name, args)
      end

      def input
        @context.input
      end

      def ensure_syntax(expr)
        @context.ensure_syntax(expr)
      end

      def raise_error(message, location)
        @context.raise_error(message, location)
      end

      def create_binding(name, location)
        Binding.new(name, loc: location)
      end
    end
  end
end
