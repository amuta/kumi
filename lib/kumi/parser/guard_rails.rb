# frozen_string_literal: true

module Kumi
  module Parser
    module GuardRails
      RESERVED = %i[input trait value fn lit ref].freeze

      def self.included(base)
        base.singleton_class.prepend(ClassMethods)
      end

      module ClassMethods
        # prevent accidental addition of new DSL keywords
        def method_added(name)
          if GuardRails::RESERVED.include?(name)
            # Check if this is a redefinition by looking at the call stack
            # We want to allow the original definition but prevent redefinition
            calling_location = caller_locations(1, 1).first

            # Allow the original definition from schema_builder.rb
            if calling_location&.path&.include?("schema_builder.rb")
              super
              return
            end

            # This is a redefinition attempt, prevent it
            raise Kumi::Errors::SemanticError,
                  "DSL keyword `#{name}` is reserved; " \
                  "do not redefine it inside SchemaBuilder"
          end
          super
        end
      end

      # catch any stray method call inside DSL block
      def method_missing(name, *_args)
        raise NoMethodError, "unknown DSL keyword `#{name}`"
      end

      def respond_to_missing?(*) = false
    end
  end
end
