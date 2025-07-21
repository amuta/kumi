# frozen_string_literal: true

module Kumi
  module FunctionRegistry
    # Type checking and conversion functions
    module TypeFunctions
      def self.definitions
        {
          fetch: FunctionBuilder::Entry.new(
            fn: ->(hash, key, default = nil) { hash.fetch(key, default) },
            arity: -1, # Variable arity (2 or 3)
            param_types: [Kumi::Types.hash(:any, :any), :any, :any],
            return_type: :any,
            description: "Fetch value from hash with optional default"
          ),

          has_key?: FunctionBuilder::Entry.new(
            fn: ->(hash, key) { hash.key?(key) },
            arity: 2,
            param_types: [Kumi::Types.hash(:any, :any), :any],
            return_type: :boolean,
            description: "Check if hash has the given key"
          ),

          keys: FunctionBuilder::Entry.new(
            fn: lambda(&:keys),
            arity: 1,
            param_types: [Kumi::Types.hash(:any, :any)],
            return_type: Kumi::Types.array(:any),
            description: "Get all keys from hash"
          ),

          values: FunctionBuilder::Entry.new(
            fn: lambda(&:values),
            arity: 1,
            param_types: [Kumi::Types.hash(:any, :any)],
            return_type: Kumi::Types.array(:any),
            description: "Get all values from hash"
          ),
          at: FunctionBuilder::Entry.new(
            fn: ->(array, index) { array[index] },
            arity: 2,
            param_types: [Kumi::Types.array(:any), :integer],
            return_type: :any,
            description: "Get element at index from array"
          )
        }
      end
    end
  end
end
