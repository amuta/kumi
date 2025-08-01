# frozen_string_literal: true

module Kumi
  module Core
    module FunctionRegistry
      # Conditional and control flow functions
      module ConditionalFunctions
        def self.definitions
          {
            conditional: FunctionBuilder::Entry.new(
              fn: ->(condition, true_value, false_value) { condition ? true_value : false_value },
              arity: 3,
              param_types: %i[boolean any any],
              return_type: :any,
              description: "Ternary conditional operator"
            ),

            if: FunctionBuilder::Entry.new(
              fn: ->(condition, true_value, false_value = nil) { condition ? true_value : false_value },
              arity: -1, # Variable arity (2 or 3)
              param_types: %i[boolean any any],
              return_type: :any,
              description: "If-then-else conditional"
            ),

            coalesce: FunctionBuilder::Entry.new(
              fn: ->(*values) { values.find { |v| !v.nil? } },
              arity: -1, # Variable arity
              param_types: [:any],
              return_type: :any,
              description: "Return first non-nil value"
            )
          }
        end
      end
    end
  end
end
