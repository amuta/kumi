# frozen_string_literal: true

module Kumi
  module Core
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
      end
    end
  end
end
