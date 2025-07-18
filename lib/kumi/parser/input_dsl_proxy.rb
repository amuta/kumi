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

      def key(name, type: :any, domain: nil)
        # Normalize the type using the simplified type system
        begin
          normalized_type = Kumi::Types.normalize(type)
        rescue ArgumentError => e
          @context.raise_error("Invalid type for input `#{name}`: #{e.message}", @context.current_location)
        end

        @context.inputs << FieldDecl.new(name, domain, normalized_type, loc: @context.current_location)
      end

      # Helper methods for complex types
      def array(elem_type)
        Kumi::Types.array(elem_type)
      end

      def hash(key_type, val_type)
        Kumi::Types.hash(key_type, val_type)
      end

      private

      def method_missing(method_name, *_args)
        @context.raise_error("Unknown method '#{method_name}' in input block. Only 'key', 'array', and 'hash' are allowed.",
                             @context.current_location)
      end

      def respond_to_missing?(_method_name, _include_private = false)
        false
      end
    end
  end
end
