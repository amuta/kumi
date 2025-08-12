# frozen_string_literal: true

module Kumi
  # Public facade for the function registry.
  # Delegates to Kumi::Core::FunctionRegistry.
  module Registry
    Entry = Core::FunctionRegistry::FunctionBuilder::Entry

    class << self
      def auto_register(*mods)
        Core::FunctionRegistry.auto_register(*mods)
      end

      def method_missing(name, ...)
        if Core::FunctionRegistry.respond_to?(name)
          Core::FunctionRegistry.public_send(name, ...)
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        Core::FunctionRegistry.respond_to?(name, include_private) || super
      end
    end
  end
end
