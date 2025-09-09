# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Base class for analyzer passes with simple immutable state
        class PassBase
          include Kumi::Syntax
          include Kumi::Core::ErrorReporting

          # @param schema [Syntax::Root] The schema to analyze
          # @param state [AnalysisState] Current analysis state
          def initialize(schema, state)
            @schema = schema
            @state = state
          end

          # Main pass execution - subclasses implement this
          # @param errors [Array] Error accumulator array
          # @return [AnalysisState] New state after pass execution
          def run(errors)
            raise NotImplementedError, "#{self.class.name} must implement #run"
          end

          protected

          attr_reader :schema, :state

          # Iterate over all declarations (values and traits) in the schema
          # @yield [Syntax::Attribute|Syntax::Trait] Each declaration
          def each_decl(&)
            schema.values.each(&)
            schema.traits.each(&)
          end

          # Get state value - compatible with old interface
          def get_state(key, required: true)
            raise StandardError, "Required state key '#{key}' not found" if required && !state.key?(key)

            state[key]
          end

          # Add error to the error list
          def add_error(errors, location, message)
            errors << ErrorReporter.create_error(message, location: location, type: :semantic)
          end

          # Debug helpers - automatic pattern based on pass class name
          # InputIndexTablePass -> DEBUG_INPUT_INDEX_TABLE=1
          # ScopeResolutionPass -> DEBUG_SCOPE_RESOLUTION=1
          def debug_enabled?
            class_name = self.class.name.split("::").last
            env_name = "DEBUG_#{to_underscore(class_name.gsub(/Pass$/, '')).upcase}"
            ENV[env_name] == "1"
          end

          def debug(message)
            class_name = self.class.name.split("::").last.gsub(/Pass$/, "")
            puts "[#{class_name}] #{message}" if debug_enabled?
          end

          private

          def to_underscore(str)
            str.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
               .gsub(/([a-z\d])([A-Z])/, '\1_\2')
               .downcase
          end
        end
      end
    end
  end
end
