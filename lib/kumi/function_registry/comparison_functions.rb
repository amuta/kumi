# frozen_string_literal: true

module Kumi::Core
  module FunctionRegistry
    # Comparison and equality functions
    module ComparisonFunctions
      def self.definitions
        {
          # Equality operators
          :== => FunctionBuilder.equality(:==, "Equality comparison", :==),
          :!= => FunctionBuilder.equality(:!=, "Inequality comparison", :!=),

          # Comparison operators
          :> => FunctionBuilder.comparison(:>, "Greater than comparison", :>),
          :< => FunctionBuilder.comparison(:<, "Less than comparison", :<),
          :>= => FunctionBuilder.comparison(:>=, "Greater than or equal comparison", :>=),
          :<= => FunctionBuilder.comparison(:<=, "Less than or equal comparison", :<=),

          # Range comparison
          :between? => FunctionBuilder::Entry.new(
            fn: ->(value, min, max) { value.between?(min, max) },
            arity: 3,
            param_types: %i[float float float],
            return_type: :boolean,
            description: "Check if value is between min and max"
          )
        }
      end
    end
  end
end
