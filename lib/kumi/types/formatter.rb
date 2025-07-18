# frozen_string_literal: true

module Kumi
  module Types
    # Formats types for display and debugging
    class Formatter
      # Convert types to string representation
      def self.type_to_s(type)
        case type
        when Hash
          if type[:array]
            "array(#{type_to_s(type[:array])})"
          elsif type[:hash]
            "hash(#{type_to_s(type[:hash][0])}, #{type_to_s(type[:hash][1])})"
          else
            type.to_s
          end
        else
          type.to_s
        end
      end
    end
  end
end
