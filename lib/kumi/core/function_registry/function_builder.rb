# frozen_string_literal: true

module Kumi
  module Core
    module FunctionRegistry
      # Utility class to reduce repetition in function definitions
      class FunctionBuilder
        Entry = Struct.new(:fn, :arity, :param_types, :return_type, :description, :inverse, :reducer, :structure_function,
                           keyword_init: true)

        def self.comparison(_name, description, operation)
          Entry.new(
            fn: ->(a, b) { a.public_send(operation, b) },
            arity: 2,
            param_types: %i[float float],
            return_type: :boolean,
            description: description
          )
        end

        def self.equality(_name, description, operation)
          Entry.new(
            fn: ->(a, b) { a.public_send(operation, b) },
            arity: 2,
            param_types: %i[any any],
            return_type: :boolean,
            description: description
          )
        end

        def self.math_binary(_name, description, operation, return_type: :float)
          Entry.new(
            fn: lambda { |a, b|
              a.public_send(operation, b)
            },
            arity: 2,
            param_types: %i[float float],
            return_type: return_type,
            description: description
          )
        end

        def self.math_unary(_name, description, operation, return_type: :float)
          Entry.new(
            fn: proc(&operation),
            arity: 1,
            param_types: [:float],
            return_type: return_type,
            description: description
          )
        end

        def self.string_unary(_name, description, operation)
          Entry.new(
            fn: ->(str) { str.to_s.public_send(operation) },
            arity: 1,
            param_types: [:string],
            return_type: :string,
            description: description
          )
        end

        def self.string_binary(_name, description, operation, return_type: :string)
          Entry.new(
            fn: ->(str, arg) { str.to_s.public_send(operation, arg.to_s) },
            arity: 2,
            param_types: %i[string string],
            return_type: return_type,
            description: description
          )
        end

        def self.logical_variadic(_name, description, operation)
          Entry.new(
            fn: ->(conditions) { conditions.public_send(operation) },
            arity: -1,
            param_types: [:boolean],
            return_type: :boolean,
            description: description
          )
        end

        def self.collection_unary(_name, description, operation, return_type: :boolean, reducer: false, structure_function: false)
          Entry.new(
            fn: proc(&operation),
            arity: 1,
            param_types: [Kumi::Core::Types.array(:any)],
            return_type: return_type,
            description: description,
            reducer: reducer,
            structure_function: structure_function
          )
        end
      end
    end
  end
end
