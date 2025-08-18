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
          def each_decl(&block)
            schema.values.each(&block)
            schema.traits.each(&block)
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

          # Access to registry from state
          def registry_v2
            state[:registry] or raise StandardError, "Registry not found in analysis state"
          end

          # Resolve function name from metadata, falling back through the chain:
          # qualified_name -> effective_fn_name -> node.fn_name
          # Always pass arity when resolving from RegistryV2
          def resolved_fn_name(metadata, node)
            metadata[:qualified_name] || metadata[:effective_fn_name] || node.fn_name
          end
        end
      end
    end
  end
end
