# frozen_string_literal: true

module Kumi
  module Core
    # Internal function registry implementation
    # Use Kumi::Registry for the public interface to register custom functions
    module FunctionRegistry
      # Re-export the Entry struct from FunctionBuilder for compatibility
      Entry = FunctionBuilder::Entry

      # Core operators that are always available
      CORE_OPERATORS = %i[== > < >= <= != between?].freeze

      # Build the complete function registry by combining all categories
      CORE_FUNCTIONS = {}.tap do |registry|
        function_modules = [
          ComparisonFunctions.definitions,
          MathFunctions.definitions,
          StringFunctions.definitions,
          LogicalFunctions.definitions,
          CollectionFunctions.definitions,
          ConditionalFunctions.definitions,
          TypeFunctions.definitions,
          StatFunctions.definitions,
          BroadcastingFunctions.definitions
        ]

        function_modules.each do |module_definitions|
          module_definitions.each do |name, definition|
            if registry.key?(name)
              raise ArgumentError, "Function #{name.inspect} is already registered. Found duplicate in function registry."
            end

            registry[name] = definition
          end
        end
      end.freeze

      @functions = CORE_FUNCTIONS.dup
      @frozen = false

      # class << self
      # Internal interface for registering custom functions
      def register(name, &block)
        raise ArgumentError, "Function #{name.inspect} already registered" if @functions.key?(name)

        fn_lambda = block.is_a?(Proc) ? block : ->(*args) { yield(*args) }
        register_with_metadata(name, fn_lambda, arity: fn_lambda.arity, param_types: [:any], return_type: :any)
      end

      # Register with custom metadata
      def register_with_metadata(name, fn_lambda, arity:, param_types: [:any], return_type: :any, description: nil,
                                 inverse: nil, reducer: false)
        raise ArgumentError, "Function #{name.inspect} already registered" if @functions.key?(name)

        @functions[name] = Entry.new(
          fn: fn_lambda,
          arity: arity,
          param_types: param_types,
          return_type: return_type,
          description: description,
          inverse: inverse,
          reducer: reducer
        )
      end

      # Auto-register functions from modules
      def auto_register(*modules)
        modules.each do |mod|
          mod.public_instance_methods(false).each do |method_name|
            next if supported?(method_name)

            register(method_name) do |*args|
              mod.new.public_send(method_name, *args)
            end
          end
        end
      end

      # Query interface
      def supported?(name)
        @functions.key?(name)
      end

      def operator?(name)
        return false unless name.is_a?(Symbol)

        @functions.key?(name) && CORE_OPERATORS.include?(name)
      end

      def fetch(name)
        @functions.fetch(name) { raise Kumi::Core::Errors::UnknownFunction, "Unknown function: #{name}" }.fn
      end

      def signature(name)
        entry = @functions.fetch(name) { raise Kumi::Core::Errors::UnknownFunction, "Unknown function: #{name}" }
        {
          arity: entry.arity,
          param_types: entry.param_types,
          return_type: entry.return_type,
          description: entry.description
        }
      end

      def all_functions
        @functions.keys
      end

      def reducer?(name)
        entry = @functions.fetch(name) { return false }
        entry.reducer || false
      end

      def structure_function?(name)
        entry = @functions.fetch(name) { return false }
        entry.structure_function || false
      end

      # Alias for compatibility
      def all
        @functions.keys
      end

      # Category accessors for introspection
      def comparison_operators
        ComparisonFunctions.definitions.keys
      end

      def math_operations
        MathFunctions.definitions.keys
      end

      def string_operations
        StringFunctions.definitions.keys
      end

      def logical_operations
        LogicalFunctions.definitions.keys
      end

      def collection_operations
        CollectionFunctions.definitions.keys
      end

      def conditional_operations
        ConditionalFunctions.definitions.keys
      end

      def type_operations
        TypeFunctions.definitions.keys
      end

      def stat_operations
        StatFunctions.definitions.keys
      end
    end
  end
end
# end
