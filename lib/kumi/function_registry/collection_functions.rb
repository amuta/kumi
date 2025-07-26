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
          ),

          # Array transformation functions
          flatten: FunctionBuilder::Entry.new(
            fn: lambda(&:flatten),
            arity: 1,
            param_types: [Kumi::Types.array(:any)],
            return_type: Kumi::Types.array(:any),
            description: "Flatten nested arrays into a single array"
          ),

          # Mathematical transformation functions
          map_multiply: FunctionBuilder::Entry.new(
            fn: ->(collection, factor) { collection.map { |x| x * factor } },
            arity: 2,
            param_types: [Kumi::Types.array(:float), :float],
            return_type: Kumi::Types.array(:float),
            description: "Multiply each element by factor"
          ),

          map_add: FunctionBuilder::Entry.new(
            fn: ->(collection, value) { collection.map { |x| x + value } },
            arity: 2,
            param_types: [Kumi::Types.array(:float), :float],
            return_type: Kumi::Types.array(:float),
            description: "Add value to each element"
          ),

          # Conditional transformation functions
          map_conditional: FunctionBuilder::Entry.new(
            fn: lambda { |collection, condition_value, true_value, false_value|
              collection.map { |x| x == condition_value ? true_value : false_value }
            },
            arity: 4,
            param_types: %i[array any any any],
            return_type: :array,
            description: "Transform elements based on condition: if element == condition_value then true_value else false_value"
          ),

          # Range/index functions for grid operations
          build_array: FunctionBuilder::Entry.new(
            fn: lambda { |size, &generator|
              (0...size).map { |i| generator ? generator.call(i) : i }
            },
            arity: 1,
            param_types: [:integer],
            return_type: Kumi::Types.array(:any),
            description: "Build array of given size with index values"
          ),

          range: FunctionBuilder::Entry.new(
            fn: ->(start, finish) { (start...finish).to_a },
            arity: 2,
            param_types: %i[integer integer],
            return_type: Kumi::Types.array(:integer),
            description: "Generate range of integers from start to finish (exclusive)"
          ),

          # Array slicing and grouping for rendering
          each_slice: FunctionBuilder::Entry.new(
            fn: ->(array, size) { array.each_slice(size).to_a },
            arity: 2,
            param_types: %i[array integer],
            return_type: Kumi::Types.array(:array),
            description: "Group array elements into subarrays of given size"
          ),

          join: FunctionBuilder::Entry.new(
            fn: lambda { |array, separator = ""|
              array.map(&:to_s).join(separator.to_s)
            },
            arity: 2,
            param_types: %i[array string],
            return_type: :string,
            description: "Join array elements into string with separator"
          ),

          # Transform each subarray to string and join the results
          map_join_rows: FunctionBuilder::Entry.new(
            fn: lambda { |array_of_arrays, row_separator = "", column_separator = "\n"|
              array_of_arrays.map { |row| row.join(row_separator.to_s) }.join(column_separator.to_s)
            },
            arity: 3,
            param_types: [Kumi::Types.array(:array), :string, :string],
            return_type: :string,
            description: "Join 2D array into string with row and column separators"
          ),

          # Higher-order collection functions (limited to common patterns)
          map_with_index: FunctionBuilder::Entry.new(
            fn: ->(collection) { collection.map.with_index.to_a },
            arity: 1,
            param_types: [Kumi::Types.array(:any)],
            return_type: Kumi::Types.array(:any),
            description: "Map collection elements to [element, index] pairs"
          ),

          indices: FunctionBuilder::Entry.new(
            fn: ->(collection) { (0...collection.size).to_a },
            arity: 1,
            param_types: [Kumi::Types.array(:any)],
            return_type: Kumi::Types.array(:integer),
            description: "Generate array of indices for the collection"
          )
        }
      end
    end
  end
end
