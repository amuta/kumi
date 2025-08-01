# frozen_string_literal: true

module Kumi
  module Core
    module RubyParser
      # Proxy for input field access that can handle arbitrary depth nesting
      # Handles input.field.subfield.subsubfield... syntax by building up path arrays
      class InputFieldProxy
        include Syntax

        # Use shared operator methods instead of refinements
        extend Sugar::ProxyRefinement

        def initialize(path, context)
          @path = Array(path) # Ensure it's always an array
          @context = context
        end

        # Convert to appropriate AST node based on path length
        def to_ast_node
          if @path.length == 1
            # Single field: input.field -> InputReference
            Kumi::Syntax::InputReference.new(@path.first, loc: @context.current_location)
          else
            # Nested fields: input.field.subfield... -> InputElementReference
            Kumi::Syntax::InputElementReference.new(@path, loc: @context.current_location)
          end
        end

        private

        def method_missing(method_name, *args, &block)
          if args.empty? && block.nil?
            # Extend the path: input.user.details -> InputFieldProxy([user, details])
            InputFieldProxy.new(@path + [method_name], @context)
          else
            # Operators are now handled by ProxyRefinement methods
            super
          end
        end

        def respond_to_missing?(_method_name, _include_private = false)
          true
        end
      end
    end
  end
end
