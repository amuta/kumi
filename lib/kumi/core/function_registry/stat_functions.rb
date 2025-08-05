# frozen_string_literal: true

module Kumi
  module Core
    module FunctionRegistry
      module StatFunctions
        def self.definitions
          {
          # Statistical Functions
          avg: FunctionBuilder::Entry.new(
            fn: lambda { |array| array.sum.to_f / array.size },
            arity: 1,
            param_types: [Kumi::Core::Types.array(:float)],
            return_type: :float,
            description: "Calculate arithmetic mean (average) of numeric collection",
            reducer: true
          ),

          mean: FunctionBuilder::Entry.new(
            fn: lambda { |array| array.sum.to_f / array.size },
            arity: 1,
            param_types: [Kumi::Core::Types.array(:float)],
            return_type: :float,
            description: "Calculate arithmetic mean (average) of numeric collection (alias for avg)",
            reducer: true
          ),

          median: FunctionBuilder::Entry.new(
            fn: lambda do |array|
              sorted = array.sort
              len = sorted.length
              if len.odd?
                sorted[len / 2]
              else
                (sorted[len / 2 - 1] + sorted[len / 2]) / 2.0
              end
            end,
            arity: 1,
            param_types: [Kumi::Core::Types.array(:float)],
            return_type: :float,
            description: "Calculate median (middle value) of numeric collection",
            reducer: true
          ),

          variance: FunctionBuilder::Entry.new(
            fn: lambda do |array|
              mean = array.sum.to_f / array.size
              sum_of_squares = array.sum { |x| (x - mean) ** 2 }
              sum_of_squares / array.size
            end,
            arity: 1,
            param_types: [Kumi::Core::Types.array(:float)],
            return_type: :float,
            description: "Calculate population variance of numeric collection",
            reducer: true
          ),

          stdev: FunctionBuilder::Entry.new(
            fn: lambda do |array|
              mean = array.sum.to_f / array.size
              sum_of_squares = array.sum { |x| (x - mean) ** 2 }
              variance = sum_of_squares / array.size
              Math.sqrt(variance)
            end,
            arity: 1,
            param_types: [Kumi::Core::Types.array(:float)],
            return_type: :float,
            description: "Calculate population standard deviation of numeric collection",
            reducer: true
          ),

          sample_variance: FunctionBuilder::Entry.new(
            fn: lambda do |array|
              return 0.0 if array.size <= 1
              mean = array.sum.to_f / array.size
              sum_of_squares = array.sum { |x| (x - mean) ** 2 }
              sum_of_squares / (array.size - 1)
            end,
            arity: 1,
            param_types: [Kumi::Core::Types.array(:float)],
            return_type: :float,
            description: "Calculate sample variance of numeric collection",
            reducer: true
          ),

          sample_stdev: FunctionBuilder::Entry.new(
            fn: lambda do |array|
              return 0.0 if array.size <= 1
              mean = array.sum.to_f / array.size
              sum_of_squares = array.sum { |x| (x - mean) ** 2 }
              variance = sum_of_squares / (array.size - 1)
              Math.sqrt(variance)
            end,
            arity: 1,
            param_types: [Kumi::Core::Types.array(:float)],
            return_type: :float,
            description: "Calculate sample standard deviation of numeric collection",
            reducer: true
          ),


          # Convenience functions for flattened statistics
          flat_size: FunctionBuilder::Entry.new(
            fn: ->(nested_array) { nested_array.flatten.size },
            arity: 1,
            param_types: [Kumi::Core::Types.array(:any)],
            return_type: :integer,
            description: "Count total elements across all nested levels",
            reducer: true
          ),

          flat_sum: FunctionBuilder::Entry.new(
            fn: ->(nested_array) { nested_array.flatten.sum },
            arity: 1,
            param_types: [Kumi::Core::Types.array(:float)],
            return_type: :float,
            description: "Sum all numeric elements across all nested levels",
            reducer: true
          ),

          flat_avg: FunctionBuilder::Entry.new(
            fn: lambda do |nested_array|
              flattened = nested_array.flatten
              flattened.sum.to_f / flattened.size
            end,
            arity: 1,
            param_types: [Kumi::Core::Types.array(:float)],
            return_type: :float,
            description: "Calculate average across all nested levels",
            reducer: true
          ),

          flat_max: FunctionBuilder::Entry.new(
            fn: ->(nested_array) { nested_array.flatten.max },
            arity: 1,
            param_types: [Kumi::Core::Types.array(:float)],
            return_type: :float,
            description: "Find maximum value across all nested levels",
            reducer: true
          ),

          flat_min: FunctionBuilder::Entry.new(
            fn: ->(nested_array) { nested_array.flatten.min },
            arity: 1,
            param_types: [Kumi::Core::Types.array(:float)],
            return_type: :float,
            description: "Find minimum value across all nested levels",
            reducer: true
          )
          }
        end
      end
    end
  end
end