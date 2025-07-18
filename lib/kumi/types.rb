# frozen_string_literal: true

module Kumi
  module Types
    # Simple symbol-based type system
    # Valid type symbols: :string, :integer, :float, :boolean, :any
    VALID_TYPES = %i[string integer float boolean any symbol regexp time date datetime].freeze

    # Type validation
    def self.valid_type?(type)
      return true if VALID_TYPES.include?(type)
      return true if type.is_a?(Hash) && type.keys == [:array] && valid_type?(type[:array])
      if type.is_a?(Hash) && type.keys.sort == [:hash] && type[:hash].is_a?(Array) && type[:hash].size == 2 &&
         valid_type?(type[:hash][0]) && valid_type?(type[:hash][1])
        return true
      end

      false
    end

    # Helper functions for complex types
    def self.array(elem_type)
      raise ArgumentError, "Invalid array element type: #{elem_type}" unless valid_type?(elem_type)

      { array: elem_type }
    end

    def self.hash(key_type, val_type)
      raise ArgumentError, "Invalid hash key type: #{key_type}" unless valid_type?(key_type)
      raise ArgumentError, "Invalid hash value type: #{val_type}" unless valid_type?(val_type)

      { hash: [key_type, val_type] }
    end

    # Type normalization - convert various inputs to canonical type symbols
    # TODO: Maybe not allow this?
    def self.normalize(type_input)
      case type_input
      when Symbol
        return type_input if VALID_TYPES.include?(type_input)

        raise ArgumentError, "Invalid type symbol: #{type_input}. Valid types: #{VALID_TYPES.join(', ')}"
      when String
        return type_input.to_sym if VALID_TYPES.include?(type_input.to_sym)

        raise ArgumentError, "Invalid type string: #{type_input}. Valid types: #{VALID_TYPES.join(', ')}"
      when Hash
        return type_input if valid_type?(type_input)

        raise ArgumentError, "Invalid complex type: #{type_input}"
      when Class
        # Backward compatibility for Ruby classes
        case type_input.name
        when "Integer" then :integer
        when "Float" then :float
        when "String" then :string
        when "TrueClass", "FalseClass" then :boolean
        when "Array" then { array: :any }
        when "Hash" then { hash: %i[any any] }
        else
          raise ArgumentError, "Unsupported Ruby class: #{type_input}. Use symbols like :string, :integer, etc."
        end
      else
        raise ArgumentError, "Type must be a symbol, string, or hash (for complex types). Got: #{type_input.class}"
      end
    end

    # Type compatibility checking
    def self.compatible?(type1, type2)
      # Normalize both types
      type1 = normalize(type1)
      type2 = normalize(type2)

      # Same types are compatible
      return true if type1 == type2

      # :any is compatible with everything
      return true if type1 == :any || type2 == :any

      # Numeric compatibility (integer and float are compatible)
      numeric_types = %i[integer float]
      return true if numeric_types.include?(type1) && numeric_types.include?(type2)

      # Array compatibility - check element types
      return compatible?(type1[:array], type2[:array]) if type1.is_a?(Hash) && type1[:array] && type2.is_a?(Hash) && type2[:array]

      # Hash compatibility - check key and value types
      if type1.is_a?(Hash) && type1[:hash] && type2.is_a?(Hash) && type2[:hash]
        return compatible?(type1[:hash][0], type2[:hash][0]) &&
               compatible?(type1[:hash][1], type2[:hash][1])
      end

      false
    end

    # Type unification - find common supertype
    def self.unify(type1, type2)
      # Normalize both types
      type1 = normalize(type1)
      type2 = normalize(type2)

      # Same types unify to themselves
      return type1 if type1 == type2

      # If one is :any, return the other
      return type2 if type1 == :any
      return type1 if type2 == :any

      # Numeric types unify to :float
      numeric_types = %i[integer float]
      if numeric_types.include?(type1) && numeric_types.include?(type2)
        return type1 == :float || type2 == :float ? :float : :integer
      end

      # Array types - unify element types
      return { array: unify(type1[:array], type2[:array]) } if type1.is_a?(Hash) && type1[:array] && type2.is_a?(Hash) && type2[:array]

      # Hash types - unify key and value types
      if type1.is_a?(Hash) && type1[:hash] && type2.is_a?(Hash) && type2[:hash]
        return { hash: [unify(type1[:hash][0], type2[:hash][0]),
                        unify(type1[:hash][1], type2[:hash][1])] }
      end

      # Otherwise, fall back to :any
      :any
    end

    # Type inference from Ruby values
    def self.infer_from_value(value)
      case value
      when Integer then :integer
      when Float then :float
      when String then :string
      when TrueClass, FalseClass then :boolean
      when Symbol then :symbol
      when Regexp then :regexp
      when Time then :time
      when Array
        return { array: :any } if value.empty?

        # Infer from first element (simple heuristic)
        { array: infer_from_value(value.first) }
      when Hash
        return { hash: %i[any any] } if value.empty?

        # Infer from first key-value pair
        first_key, first_value = value.first
        { hash: [infer_from_value(first_key), infer_from_value(first_value)] }
      else
        # Handle optional dependencies
        return :date if defined?(Date) && value.is_a?(Date)
        return :datetime if defined?(DateTime) && value.is_a?(DateTime)

        :any
      end
    end

    # Convert types to string representation
    def self.type_to_s(type)
      case type
      when Symbol
        type.to_s
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

    # Legacy compatibility constants (will be phased out)
    # These should be replaced with symbols in user code over time
    STRING = :string
    INT = :integer # NOTE: using :integer instead of :int for clarity
    FLOAT = :float
    BOOL = :boolean # NOTE: using :boolean instead of :bool for clarity
    ANY = :any
    SYMBOL = :symbol
    REGEXP = :regexp
    TIME = :time
    DATE = :date
    DATETIME = :datetime

    # Legacy compatibility for numeric union
    NUMERIC = :float # Simplified - just use float for numeric operations

    # Legacy method for backward compatibility
    def self.coerce(type_input)
      # Handle legacy constant usage
      return type_input if type_input.is_a?(Symbol) && VALID_TYPES.include?(type_input)

      # Handle legacy constant objects
      case type_input
      when STRING then :string
      when INT then :integer
      when FLOAT then :float
      when BOOL then :boolean
      when ANY then :any
      when SYMBOL then :symbol
      when REGEXP then :regexp
      when TIME then :time
      when DATE then :date
      when DATETIME then :datetime
      when NUMERIC then :float
      else
        normalize(type_input)
      end
    end
  end
end
