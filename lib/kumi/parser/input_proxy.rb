# frozen_string_literal: true


module Kumi
  module Parser
    # Proxy object for input field references (input.field_name)
    class InputProxy
      include Syntax::TerminalExpressions

      def initialize(context)
        @context = context
      end

      private

      # This method is called when the user tries to access a field
      # on the input object, e.g. `input.field_name`.
      # It is used to create a FieldRef node in the AST.
      def method_missing(method_name, *_args)
        FieldRef.new(method_name, loc: @context.current_location)
      end

      def respond_to_missing?(_method_name, _include_private = false)
        true # Allow any field name
      end
    end
  end
end
