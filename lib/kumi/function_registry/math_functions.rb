# frozen_string_literal: true

module Kumi
  module FunctionRegistry
    # Mathematical operations
    module MathFunctions
      def self.definitions
        {
          # Basic arithmetic
          add: FunctionBuilder.math_binary(:add, "Add two numbers", :+),
          subtract: FunctionBuilder.math_binary(:subtract, "Subtract second number from first", :-),
          multiply: FunctionBuilder.math_binary(:multiply, "Multiply two numbers", :*),
          divide: FunctionBuilder.math_binary(:divide, "Divide first number by second", :/),
          modulo: FunctionBuilder.math_binary(:modulo, "Modulo operation", :%),
          power: FunctionBuilder.math_binary(:power, "Raise first number to power of second", :**),

          # Unary operations
          abs: FunctionBuilder.math_unary(:abs, "Absolute value", :abs),
          floor: FunctionBuilder.math_unary(:floor, "Floor of number", :floor, return_type: :integer),
          ceil: FunctionBuilder.math_unary(:ceil, "Ceiling of number", :ceil, return_type: :integer),

          # Special operations
          round: FunctionBuilder::Entry.new(
            fn: ->(a, precision = 0) { a.round(precision) },
            arity: -1,
            param_types: [:float],
            return_type: :float,
            description: "Round number to specified precision"
          ),

          clamp: FunctionBuilder::Entry.new(
            fn: ->(value, min, max) { value.clamp(min, max) },
            arity: 3,
            param_types: %i[float float float],
            return_type: :float,
            description: "Clamp value between min and max"
          ),
          tiered_sum: FunctionBuilder::Entry.new(
            # Tiered / piece‑wise accumulator ­­­­­­­­­­­­­­­­­­­­­­­­­
            fn: lambda do |value, breaks, rates|
              raise ArgumentError, "breaks & rates size mismatch" unless breaks.size == rates.size

              acc      = 0.0
              previous = 0.0
              marginal = rates.last

              breaks.zip(rates).each do |upper, rate|
                if value <= upper
                  marginal = rate
                  acc += (value - previous) * rate
                  break
                else
                  acc += (upper - previous) * rate
                  previous = upper
                end
              end
              [acc, marginal]                              # => [sum, marginal_rate]
            end,
            arity: 3,
            param_types: [
              :float,
              Kumi::Types.array(:float),                   # breaks
              Kumi::Types.array(:float)                    # rates
            ],
            return_type: Kumi::Types.array(:float),        # 2‑element [sum, marginal]
            description: "Accumulate over tiered ranges; returns [sum, marginal_rate]"
          )
        }
      end
    end
  end
end
