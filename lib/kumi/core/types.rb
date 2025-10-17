# frozen_string_literal: true

require_relative 'types/value_objects'

module Kumi
  module Core
    module Types
      # Re-export constants for compatibility
      VALID_TYPES = Validator::VALID_TYPES

      def self.collection?(dtype)
        tuple?(dtype) || array?(dtype)
      end

      def self.tuple?(dtype)
        return dtype.is_a?(TupleType) if dtype.is_a?(Type)
        # Legacy string/symbol support for backwards compatibility
        dtype == :tuple || dtype.to_s.match?(/^tuple</)
      end

      def self.array?(dtype)
        return dtype.is_a?(ArrayType) if dtype.is_a?(Type)
        # Legacy string/symbol support for backwards compatibility
        dtype == :array || dtype.to_s.match?(/^array</)
      end

      # Validation methods
      def self.valid_type?(type)
        Validator.valid_type?(type)
      end

      # Type value object constructors
      def self.scalar(kind)
        ScalarType.new(kind)
      end

      def self.array(element_type)
        elem_obj = case element_type
                   when Type
                     element_type
                   when :string, :integer, :float, :boolean, :hash, :any, :symbol, :regexp, :time, :date, :datetime, :null
                     scalar(element_type)
                   else
                     raise ArgumentError,
                           "array element must be Type object or scalar kind, got #{element_type.inspect}"
                   end
        ArrayType.new(elem_obj)
      end

      def self.tuple(element_types)
        if element_types.is_a?(Array) && element_types.all? { |t| t.is_a?(Type) }
          TupleType.new(element_types)
        else
          raise ArgumentError, "tuple expects array of Type objects"
        end
      end

      def self.hash(key_type, val_type)
        raise NotImplementedError, "Use scalar(:hash) instead - Kumi treats hash as scalar, not key/value pair"
      end

      # Normalization
      def self.normalize(type_input)
        Normalizer.normalize(type_input)
      end

      def self.coerce(type_input)
        Normalizer.coerce(type_input)
      end

      # Type inference
      def self.infer_from_value(value)
        Inference.infer_from_value(value)
      end

      # Legacy compatibility constants (will be phased out)
      # These should be replaced with symbols in user code over time
      STRING = :string
      INT = :integer # NOTE: using :integer instead of :int for clarity
      FLOAT = :float
      BOOL = :boolean
      ANY = :any
      SYMBOL = :symbol
      REGEXP = :regexp
      TIME = :time
      DATE = :date
      DATETIME = :datetime
      NUMERIC = :float # Legacy: represents numeric compatibility
    end
  end
end
