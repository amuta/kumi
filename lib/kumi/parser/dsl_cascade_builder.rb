# frozen_string_literal: true

require "forwardable"

module Kumi
  module Parser
    class DslCascadeBuilder
      include Syntax

      extend Forwardable

      attr_reader :cases

      def_delegators :@context, :ref, :literal, :fn, :input, :ensure_syntax, :raise_error

      def initialize(context, loc)
        @context = context
        @cases   = []
        @loc = loc
        @else = nil
      end

      def on(*args)
        # Capture the caller location for precise error reporting
        c = caller_locations(1, 1).first
        on_loc = Location.new(file: c.path, line: c.lineno, column: 0)

        @context.raise_error("cascade 'on' requires at least one trait name", on_loc) if args.empty?

        @context.raise_error("cascade 'on' requires an expression as the last argument", on_loc) if args.size == 1

        trait_names = args[0..-2]
        expr = args.last

        condition = fn(:all?, trait_names.map { |name| ref_with_location(name, on_loc) })
        result    = ensure_syntax(expr, @loc)
        @cases << WhenCaseExpression.new(condition, result)
      end

      def on_any(*args)
        # Capture the caller location for precise error reporting
        c = caller_locations(1, 1).first
        on_loc = Location.new(file: c.path, line: c.lineno, column: 0)

        @context.raise_error("cascade 'on_any' requires at least one trait name", on_loc) if args.empty?

        @context.raise_error("cascade 'on_any' requires an expression as the last argument", on_loc) if args.size == 1

        trait_names = args[0..-2]
        expr = args.last

        condition = fn(:any?, trait_names.map { |name| ref_with_location(name, on_loc) })
        result    = ensure_syntax(expr, @loc)
        @cases << WhenCaseExpression.new(condition, result)
      end

      def on_none(*args)
        # Capture the caller location for precise error reporting
        c = caller_locations(1, 1).first
        on_loc = Location.new(file: c.path, line: c.lineno, column: 0)

        @context.raise_error("cascade 'on_none' requires at least one trait name", on_loc) if args.empty?

        @context.raise_error("cascade 'on_none' requires an expression as the last argument", on_loc) if args.size == 1

        trait_names = args[0..-2]
        expr = args.last

        condition = fn(:none?, trait_names.map { |name| ref_with_location(name, on_loc) })
        result    = ensure_syntax(expr, @loc)
        @cases << WhenCaseExpression.new(condition, result)
      end

      def base(expr)
        result = ensure_syntax(expr, @loc)
        @cases << WhenCaseExpression.new(literal(true), result) # Always matches
      end

      def method_missing(method_name, *args, &block)
        super if !args.empty? || block_given?
        # You can reference values directly or with ref(:name) syntax
        # value :one "one"
        # value :points_to_one, one
        # value_:also_points_to_one, ref(:one)
        Binding.new(method_name, loc: @loc)
      end

      def respond_to_missing?(_method_name, _include_private = false)
        true
      end

      private

      # Helper method to create a Binding with a specific location
      def ref_with_location(name, loc)
        Binding.new(name, loc: loc)
      end
    end
  end
end
