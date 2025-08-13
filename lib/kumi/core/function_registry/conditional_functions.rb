# frozen_string_literal: true

module Kumi
  module Core
    module FunctionRegistry
      module ConditionalFunctions
        def self.definitions
          {
            # a ? b : c
            conditional: FunctionBuilder::Entry.new(
              fn: ->(condition, true_value, false_value) { condition ? true_value : false_value },
              arity: 3,
              param_types: %i[boolean any any],
              return_type: :any,
              # all three are element-wise (scalars auto-broadcast)
              param_modes: { fixed: %i[elem elem elem] },
              description: "Ternary conditional operator"
            ),

            # if(cond, then, else=nil)
            if: FunctionBuilder::Entry.new(
              fn: ->(condition, true_value, false_value = nil) { condition ? true_value : false_value },
              # keep arity=3; the last arg is optional at call time
              arity: 3,
              param_types: %i[boolean any any],
              return_type: :any,
              param_modes: { fixed: %i[elem elem elem] },
              description: "If-then-else conditional",
              reducer: false,
              structure_function: false
            ),

            # coalesce(a, b, c, ...)
            coalesce: FunctionBuilder::Entry.new(
              fn: ->(*values) { values.find { |v| !v.nil? } },
              arity: -1, # variadic
              param_types: [:any],
              return_type: :any,
              # every variadic arg participates element-wise
              param_modes: { fixed: [], variadic: :elem },
              description: "Return first non-nil value"
            )
          }
        end
      end
    end
  end
end
