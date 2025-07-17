# frozen_string_literal: true

module Kumi
  module Parser
    # Proxy class for the input block DSL
    # Only exposes the key() method for field declarations
    class InputDslProxy
      include Syntax

      # We define these so they can be used in the DSL
      Bool       = Kumi::Types::BOOL
      Any        = Kumi::Types::ANY

      def initialize(context)
        @context = context
      end

      def key(name, type: Any, domain: nil)
        type = Kumi::Types.coerce(type)

        unless type.is_a?(Kumi::Types::Base)
          @context.raise_error("Undefined type class `#{type}` for input `#{name}`. Use a valid Kumi type or Ruby class.",
                               @context.current_location)
        end

        @context.inputs << FieldDecl.new(name, domain, type, loc: @context.current_location)
      end

      private

      def method_missing(method_name, *_args)
        @context.raise_error("Unknown method '#{method_name}' in input block. Only 'key' is allowed.", @context.current_location)
      end

      def respond_to_missing?(_method_name, _include_private = false)
        false
      end
    end
  end
end
