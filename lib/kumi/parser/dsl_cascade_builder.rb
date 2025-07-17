# frozen_string_literal: true

require "forwardable"

module Kumi
  module Parser
    class DslCascadeBuilder
      include Syntax::Expressions

      extend Forwardable

      attr_reader :cases

      def_delegators :@context, :ref, :literal, :fn, :input

      def initialize(context, loc)
        @context = context
        @cases   = []
        @loc = loc
        @else = nil
      end

      def on(*trait_names, expr)
        loc = @context.send(:current_location)
        condition = fn(:all?, trait_names.map { |name| ref(name) })
        result    = @context.send(:ensure_syntax, expr, loc)
        @cases << WhenCaseExpression.new(condition, result)
      end

      def on_any(*trait_names, expr)
        loc = @context.send(:current_location)
        condition = fn(:any?, trait_names.map { |name| ref(name) })
        result    = @context.send(:ensure_syntax, expr, loc)
        @cases << WhenCaseExpression.new(condition, result)
      end

      def on_none(*trait_names, expr)
        loc = @context.send(:current_location)
        condition = fn(:none?, trait_names.map { |name| ref(name) })
        result    = @context.send(:ensure_syntax, expr, loc)
        @cases << WhenCaseExpression.new(condition, result)
      end

      def base(expr)
        result = @context.send(:ensure_syntax, expr, @loc)
        @cases << WhenCaseExpression.new(literal(true), result) # Always matches
      end
    end
  end
end
