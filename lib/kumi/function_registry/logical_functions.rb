# frozen_string_literal: true

module Kumi
  module FunctionRegistry
    # Logical operations and boolean functions
    module LogicalFunctions
      def self.definitions
        {
          # Basic logical operations
          and: FunctionBuilder::Entry.new(
            fn: ->(*conditions) { conditions.all? },
            arity: -1,
            param_types: [:boolean],
            return_type: :boolean,
            description: "Logical AND of multiple conditions"
          ),

          or: FunctionBuilder::Entry.new(
            fn: ->(*conditions) { conditions.any? },
            arity: -1,
            param_types: [:boolean],
            return_type: :boolean,
            description: "Logical OR of multiple conditions"
          ),

          not: FunctionBuilder::Entry.new(
            fn: lambda(&:!),
            arity: 1,
            param_types: [:boolean],
            return_type: :boolean,
            description: "Logical NOT"
          ),

          # Collection logical operations
          all?: FunctionBuilder.collection_unary(:all?, "Check if all elements in collection are truthy", :all?),
          any?: FunctionBuilder.collection_unary(:any?, "Check if any element in collection is truthy", :any?),
          none?: FunctionBuilder.collection_unary(:none?, "Check if no elements in collection are truthy", :none?)
        }
      end
    end
  end
end
