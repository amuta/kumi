# frozen_string_literal: true

module Kumi
  module FunctionRegistry
    # Collection manipulation and query functions
    module CollectionFunctions
      def self.definitions
        {
          # Collection queries
          empty?: FunctionBuilder.collection_unary(:empty?, "Check if collection is empty", :empty?),
          size: FunctionBuilder.collection_unary(:size, "Get collection size", :size, return_type: :integer),
          length: FunctionBuilder.collection_unary(:length, "Get collection length", :length, return_type: :integer),

          # Element access
          first: FunctionBuilder::Entry.new(
            fn: lambda(&:first),
            arity: 1,
            param_types: [Kumi::Types.array(:any)],
            return_type: :any,
            description: "Get first element of collection"
          ),

          last: FunctionBuilder::Entry.new(
            fn: lambda(&:last),
            arity: 1,
            param_types: [Kumi::Types.array(:any)],
            return_type: :any,
            description: "Get last element of collection"
          ),

          # Mathematical operations on collections
          sum: FunctionBuilder::Entry.new(
            fn: lambda(&:sum),
            arity: 1,
            param_types: [Kumi::Types.array(:float)],
            return_type: :float,
            description: "Sum all numeric elements in collection"
          ),

          min: FunctionBuilder::Entry.new(
            fn: lambda(&:min),
            arity: 1,
            param_types: [Kumi::Types.array(:float)],
            return_type: :float,
            description: "Find minimum value in numeric collection"
          ),

          max: FunctionBuilder::Entry.new(
            fn: lambda(&:max),
            arity: 1,
            param_types: [Kumi::Types.array(:float)],
            return_type: :float,
            description: "Find maximum value in numeric collection"
          ),

          # Collection operations
          include?: FunctionBuilder::Entry.new(
            fn: ->(collection, element) { collection.include?(element) },
            arity: 2,
            param_types: [Kumi::Types.array(:any), :any],
            return_type: :boolean,
            description: "Check if collection includes element"
          ),

          reverse: FunctionBuilder::Entry.new(
            fn: lambda(&:reverse),
            arity: 1,
            param_types: [Kumi::Types.array(:any)],
            return_type: Kumi::Types.array(:any),
            description: "Reverse collection order"
          ),

          sort: FunctionBuilder::Entry.new(
            fn: lambda(&:sort),
            arity: 1,
            param_types: [Kumi::Types.array(:any)],
            return_type: Kumi::Types.array(:any),
            description: "Sort collection"
          ),

          unique: FunctionBuilder::Entry.new(
            fn: lambda(&:uniq),
            arity: 1,
            param_types: [Kumi::Types.array(:any)],
            return_type: Kumi::Types.array(:any),
            description: "Remove duplicate elements from collection"
          )
        }
      end
    end
  end
end
