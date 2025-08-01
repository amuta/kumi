# frozen_string_literal: true

module Kumi
  module RubyParser
    # DSL proxy for declaration references (traits and values)
    # Handles references to declared items and field access on them
    class DeclarationReferenceProxy
      include Syntax

      # Use shared operator methods
      extend Sugar::ProxyRefinement

      def initialize(name, context)
        @name = name
        @context = context
      end

      # Convert to DeclarationReference AST node
      def to_ast_node
        Kumi::Syntax::DeclarationReference.new(@name, loc: @context.current_location)
      end

      private

      def method_missing(method_name, *args, &block)
        # All operators are handled by ProxyRefinement methods
        # Field access should use input.field.subfield syntax, not bare identifiers
        super
      end

      def respond_to_missing?(_method_name, _include_private = false)
        true
      end
    end
  end
end
