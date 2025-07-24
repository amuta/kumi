# frozen_string_literal: true

module Kumi
  module Types
    # Validates type definitions and structures
    class Validator
      VALID_TYPES = %i[string integer float boolean any symbol regexp time date datetime array].freeze

      def self.valid_type?(type)
        return true if VALID_TYPES.include?(type)
        return true if array_type?(type)
        return true if hash_type?(type)

        false
      end

      def self.array_type?(type)
        type.is_a?(Hash) && type.keys == [:array] && valid_type?(type[:array])
      end

      def self.hash_type?(type)
        type.is_a?(Hash) &&
          type.keys.sort == [:hash] &&
          type[:hash].is_a?(Array) &&
          type[:hash].size == 2 &&
          valid_type?(type[:hash][0]) &&
          valid_type?(type[:hash][1])
      end

      def self.primitive_type?(type)
        VALID_TYPES.include?(type)
      end
    end
  end
end
