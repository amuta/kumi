# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      # This module provides pure Ruby implementations of primitive functions
      # specifically for the ConstantEvaluator to use at compile time.
      # This approach avoids all use of `eval` and is fast and secure.
      # It is references by the functions data yamls, as folding_method
      module ConstantFoldingHelpers
        module_function

        # :agg :booleans
        def all?(collection) = collection.all?
        def any?(collection) = collection.any?

        # :agg :numeric
        def sum(collection) = collection.sum
        def count(collection) = collection.size
        def avg(collection) = collection.sum.to_f / collection.size
        def min(collection) = collection.min
        def max(collection) = collection.max

        # :core :numeric
        def add(a, b) = a + b
        def sub(a, b) = a - b
        def mul(a, b) = a * b
        def div(a, b) = a.to_f / b
        def mod(a, b) = a % b
        def at(collection, index) = collection[index]

        # :core :booleans
        def and(a, b) = a && b
        def or(a, b)  = a || b
        def not?(a) = !a

        # :core :comparisons
        def lt?(a, b) = a < b
        def gt?(a, b) = a > b
        def gte?(a, b) = a >= b
        def eq?(a, b)  = a == b
        def neq?(a, b) = a != b

        # :core :constructor
        def length(collection) = collection.size
        def tuple(*args) = args

        # :core :select
        def select(condition_mask, value_when_true, value_when_false)
          condition_mask ? value_when_true : value_when_false
        end
      end
    end
  end
end
