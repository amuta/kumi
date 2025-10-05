# frozen_string_literal: true

module Kumi
  module Core
    module Types
      # Re-export constants for compatibility
      VALID_TYPES = Validator::VALID_TYPES

      def self.collection?(dtype)
        tuple?(dtype) || array?(dtype)
      end

      def self.tuple?(dtype) = dtype == :tuple || dtype.match?(/^tuple</)
      def self.array?(dtype) = dtype == :array || dtype.match?(/^array</)

      # Validation methods
      def self.valid_type?(type)
        Validator.valid_type?(type)
      end

      # Type builders
      def self.array(elem_type)
        Builder.array(elem_type)
      end

      def self.hash(key_type, val_type)
        Builder.hash(key_type, val_type)
      end

      # Normalization
      def self.normalize(type_input)
        Normalizer.normalize(type_input)
      end

      def self.coerce(type_input)
        Normalizer.coerce(type_input)
      end

      # Compatibility and unification
      def self.compatible?(type1, type2)
        Compatibility.compatible?(type1, type2)
      end

      def self.unify(type1, type2)
        Compatibility.unify(type1, type2)
      end

      # Type inference
      def self.infer_from_value(value)
        Inference.infer_from_value(value)
      end

      # Formatting
      def self.type_to_s(type)
        Formatter.type_to_s(type)
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
