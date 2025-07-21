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

      def on(*trait_names, expr)
        condition = fn(:all?, trait_names.map { |name| ref(name) })
        result    = ensure_syntax(expr, @loc)
        @cases << WhenCaseExpression.new(condition, result)
      end

      def on_any(*trait_names, expr)
        condition = fn(:any?, trait_names.map { |name| ref(name) })
        result    = ensure_syntax(expr, @loc)
        @cases << WhenCaseExpression.new(condition, result)
      end

      def on_none(*trait_names, expr)
        condition = fn(:none?, trait_names.map { |name| ref(name) })
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
    end
  end
end
