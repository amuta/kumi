# frozen_string_literal: true

require "forwardable"

module Kumi
  module Parser
    class DslCascadeBuilder
      include Syntax::Expressions

      extend Forwardable

      attr_reader :cases, :default

      def_delegators :@context, :ref, :literal, :key, :fn

      def initialize(context, loc)
        @context = context
        @cases   = []
        @loc = loc
        @default = nil
      end

      def on_trait(trait_name, expr)
        on_traits(trait_name, expr)
      end

      def on_traits(*trait_names, expr)
        loc = @context.send(:current_location)
        condition = fn(:all?, trait_names.map { |name| ref(name) })
        result    = @context.send(:ensure_syntax, expr, loc)
        @cases << WhenCaseExpression.new(condition, result)
      end

      def default(expr)
        result = @context.send(:ensure_syntax, expr, @loc)
        @cases << WhenCaseExpression.new(literal(true), result) # Always matches
      end
    end
  end
end
