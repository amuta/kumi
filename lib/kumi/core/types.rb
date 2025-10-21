# frozen_string_literal: true

require_relative "types/value_objects"

module Kumi
  module Core
    module Types
      # Re-export constants for compatibility
      VALID_TYPES = Validator::VALID_TYPES

      def self.collection?(dtype)
        tuple?(dtype) || array?(dtype)
      end

      def self.tuple?(dtype)
        dtype.is_a?(TupleType)
      end

      def self.array?(dtype)
        dtype.is_a?(ArrayType)
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
                   when :string, :integer, :float, :decimal, :boolean, :hash, :any, :symbol, :regexp, :time, :date, :datetime, :null
                     scalar(element_type)
                   else
                     raise ArgumentError,
                           "array element must be Type object or scalar kind, got #{element_type.inspect}"
                   end
        ArrayType.new(elem_obj)
      end

      def self.tuple(element_types)
        raise ArgumentError, "tuple expects array of Type objects, got #{element_types.class}" unless element_types.is_a?(Array)

        # Convert any non-Type elements to Type objects
        converted = element_types.map do |t|
          case t
          when Type
            t
          when :string, :integer, :float, :decimal, :boolean, :hash, :any, :symbol, :regexp, :time, :date, :datetime, :null
            scalar(t)
          else
            raise ArgumentError, "tuple element must be Type or scalar kind, got #{t.inspect}"
          end
        end

        TupleType.new(converted)
      end

      def self.hash(key_type, val_type)
        raise NotImplementedError, "Use scalar(:hash) instead - Kumi treats hash as scalar, not key/value pair"
      end

      # Normalization
      def self.normalize(type_input)
        Normalizer.normalize(type_input)
      end

      # Type inference
      def self.infer_from_value(value)
        Inference.infer_from_value(value)
      end
    end
  end
end
