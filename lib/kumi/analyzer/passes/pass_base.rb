# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      # Base class for all analyzer passes providing common functionality
      # and enforcing consistent interface patterns.
      class PassBase
        include Kumi::Syntax

        # @param schema [Syntax::Root] The schema to analyze
        # @param state [Hash] Shared analysis state accumulator
        def initialize(schema, state)
          @schema = schema
          @state = state
        end

        # Main entry point for pass execution
        # @param errors [Array] Error accumulator array
        # @abstract Subclasses must implement this method
        def run(errors)
          raise NotImplementedError, "#{self.class.name} must implement #run"
        end

        protected

        attr_reader :schema, :state

        # Iterate over all declarations (attributes and traits) in the schema
        # @yield [Syntax::Declarations::Attribute|Syntax::Declarations::Trait] Each declaration
        def each_decl(&block)
          schema.attributes.each(&block)
          schema.traits.each(&block)
        end

        # Helper to add standardized error messages
        # @param errors [Array] Error accumulator
        # @param location [Syntax::Location] Error location
        # @param message [String] Error message
        def add_error(errors, location, message)
          errors << [location, message]
        end

        # Helper to get required state from previous passes
        # @param key [Symbol] State key to retrieve
        # @param required [Boolean] Whether this state is required
        # @return [Object] The state value
        # @raise [StandardError] If required state is missing
        def get_state(key, required: true)
          value = state[key]
          if required && value.nil?
            raise "Pass #{self.class.name} requires #{key} from previous passes, but it was not found"
          end
          value
        end

        # Helper to set state for subsequent passes
        # @param key [Symbol] State key to set
        # @param value [Object] Value to store
        def set_state(key, value)
          state[key] = value
        end
      end
    end
  end
end