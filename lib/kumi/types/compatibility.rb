# frozen_string_literal: true

module Kumi
  module Types
    # Handles type compatibility and unification
    class Compatibility
      # Check if two types are compatible
      def self.compatible?(type1, type2)
        # Any type is compatible with anything
        return true if type1 == :any || type2 == :any

        # Exact match
        return true if type1 == type2

        # Generic array compatibility: :array is compatible with any structured array
        return true if (type1 == :array && Validator.array_type?(type2)) ||
                       (type2 == :array && Validator.array_type?(type1))

        # Numeric compatibility
        return true if numeric_compatible?(type1, type2)

        # Array compatibility
        return array_compatible?(type1, type2) if array_types?(type1, type2)

        # Hash compatibility
        return hash_compatible?(type1, type2) if hash_types?(type1, type2)

        false
      end

      # Find the most specific common type between two types
      def self.unify(type1, type2)
        return type1 if type1 == type2

        # :any unifies to the other type (more specific)
        return type2 if type1 == :any
        return type1 if type2 == :any

        # Generic array unification: structured array is more specific than :array
        return type2 if type1 == :array && Validator.array_type?(type2)
        return type1 if type2 == :array && Validator.array_type?(type1)

        # Numeric unification
        if numeric_compatible?(type1, type2)
          return :integer if type1 == :integer && type2 == :integer

          return :float # One or both are float
        end

        # Array unification
        if array_types?(type1, type2)
          elem1 = type1[:array]
          elem2 = type2[:array]
          unified_elem = unify(elem1, elem2)
          return Kumi::Types.array(unified_elem)
        end

        # Hash unification
        if hash_types?(type1, type2)
          key1, val1 = type1[:hash]
          key2, val2 = type2[:hash]
          unified_key = unify(key1, key2)
          unified_val = unify(val1, val2)
          return Kumi::Types.hash(unified_key, unified_val)
        end

        # Fall back to :any for incompatible types
        :any
      end

      def self.numeric_compatible?(type1, type2)
        numeric_types = %i[integer float]
        numeric_types.include?(type1) && numeric_types.include?(type2)
      end

      def self.array_types?(type1, type2)
        Validator.array_type?(type1) && Validator.array_type?(type2)
      end

      def self.hash_types?(type1, type2)
        Validator.hash_type?(type1) && Validator.hash_type?(type2)
      end

      def self.array_compatible?(type1, type2)
        compatible?(type1[:array], type2[:array])
      end

      def self.hash_compatible?(type1, type2)
        compatible?(type1[:hash][0], type2[:hash][0]) &&
          compatible?(type1[:hash][1], type2[:hash][1])
      end
    end
  end
end
