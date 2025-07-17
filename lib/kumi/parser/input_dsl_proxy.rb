# frozen_string_literal: true

module Kumi
  module Parser
    # Proxy class for the input block DSL
    # Only exposes the key() method for field declarations
    class InputDslProxy
      include Syntax

      def initialize(context)
        @context = context
      end

      def key(name, type: nil, domain: nil)
        type ||= Kumi::Types::ANY
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
