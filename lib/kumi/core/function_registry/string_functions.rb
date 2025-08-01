# frozen_string_literal: true

module Kumi::Core
  module FunctionRegistry
    # String manipulation functions
    module StringFunctions
      def self.definitions
        {
          # String transformations
          upcase: FunctionBuilder.string_unary(:upcase, "Convert string to uppercase", :upcase),
          downcase: FunctionBuilder.string_unary(:downcase, "Convert string to lowercase", :downcase),
          capitalize: FunctionBuilder.string_unary(:capitalize, "Capitalize first letter of string", :capitalize),
          strip: FunctionBuilder.string_unary(:strip, "Remove leading and trailing whitespace", :strip),

          # String queries
          string_length: FunctionBuilder::Entry.new(
            fn: ->(str) { str.to_s.length },
            arity: 1,
            param_types: [:string],
            return_type: :integer,
            description: "Get string length"
          ),

          # Keep the original length for backward compatibility, but it will be overridden
          length: FunctionBuilder::Entry.new(
            fn: ->(str) { str.to_s.length },
            arity: 1,
            param_types: [:string],
            return_type: :integer,
            description: "Get string length"
          ),

          # String inclusion using different name to avoid conflict with collection include?
          string_include?: FunctionBuilder.string_binary(:include?, "Check if string contains substring", :include?, return_type: :boolean),
          includes?: FunctionBuilder.string_binary(:include?, "Check if string contains substring", :include?, return_type: :boolean),
          contains?: FunctionBuilder.string_binary(:include?, "Check if string contains substring", :include?, return_type: :boolean),

          start_with?: FunctionBuilder.string_binary(:start_with?, "Check if string starts with prefix", :start_with?,
                                                     return_type: :boolean),
          end_with?: FunctionBuilder.string_binary(:end_with?, "Check if string ends with suffix", :end_with?, return_type: :boolean),

          # String building
          concat: FunctionBuilder::Entry.new(
            fn: ->(*strings) { strings.join },
            arity: -1,
            param_types: [:string],
            return_type: :string,
            description: "Concatenate multiple strings"
          )
        }
      end
    end
  end
end
