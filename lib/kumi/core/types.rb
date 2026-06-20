# frozen_string_literal: true

# value_objects.rb defines ScalarType/ArrayType/TupleType/Type, whose constant
# names do not match the filename, so Zeitwerk cannot autoload them. Require it
# explicitly; everything else under types/ is autoloaded by convention.
require_relative "types/value_objects"

module Kumi
  module Core
    # The Types facade: the stable public surface for constructing and querying
    # types. Construction and predicates live here; all type *policy* (promotion,
    # categories, constraint compatibility) lives in Types::System, and the kind
    # table + canonical-string parsing live in Types::Registry.
    module Types
      def self.collection?(dtype)
        tuple?(dtype) || array?(dtype)
      end

      def self.tuple?(dtype)
        dtype.is_a?(TupleType)
      end

      def self.array?(dtype)
        dtype.is_a?(ArrayType)
      end

      def self.valid_type?(type)
        Registry.valid?(type)
      end

      # ---- constructors -------------------------------------------------------

      def self.scalar(kind)
        raise ArgumentError, "unknown scalar kind: #{kind.inspect}" unless Registry.kind?(kind)

        ScalarType.new(kind)
      end

      def self.array(element_type)
        ArrayType.new(coerce(element_type, context: "array element"))
      end

      def self.tuple(element_types)
        raise ArgumentError, "tuple expects an array of types, got #{element_types.class}" unless element_types.is_a?(Array)

        TupleType.new(element_types.map { |t| coerce(t, context: "tuple element") })
      end

      # ---- parsing / normalization -------------------------------------------

      # Parse the canonical string form back into a Type object (inverse of
      # Type#to_s): "array<integer>" -> ArrayType(ScalarType(:integer)).
      def self.parse(str)
        Registry.parse(str)
      end

      def self.normalize(type_input)
        Normalizer.normalize(type_input)
      end

      # ---- inference / policy -------------------------------------------------

      def self.infer_from_value(value)
        Inference.infer_from_value(value)
      end

      # Convenience delegates to the default type-system policy.
      def self.promote(*types)    = System.default.promote(*types)
      def self.unify(left, right) = System.default.unify(left, right)
      def self.element_of(type)   = System.default.element_of(type)

      # Coerce a Type object or scalar-kind symbol into a Type object.
      def self.coerce(value, context:)
        case value
        when Type then value
        when Symbol
          raise ArgumentError, "#{context} must be a known scalar kind, got #{value.inspect}" unless Registry.kind?(value)

          ScalarType.new(value)
        else
          raise ArgumentError, "#{context} must be a Type or scalar kind, got #{value.inspect}"
        end
      end
    end
  end
end
