# frozen_string_literal: true

module Kumi
  module Types
    class Base
      def |(other)
        Union.new(self, other)
      end
    end

    class Primitive < Base
      include Comparable

      attr_reader :name

      def initialize(name)
        @name = name
      end

      def <=>(other)
        name <=> other.name
      end

      def to_s
        name.to_s
      end

      def inspect
        "Types::#{name.to_s.upcase}"
      end

      def ==(other)
        other.is_a?(Primitive) && name == other.name
      end

      def hash
        [self.class, name].hash
      end
    end

    class ArrayOf < Base
      attr_reader :elem

      def initialize(elem)
        @elem = elem
      end

      def to_s
        "array<#{elem}>"
      end

      def inspect
        "Types::ArrayOf(#{elem.inspect})"
      end

      def ==(other)
        other.is_a?(ArrayOf) && elem == other.elem
      end

      def hash
        [self.class, elem].hash
      end
    end

    class SetOf < Base
      attr_reader :elem

      def initialize(elem)
        @elem = elem
      end

      def to_s
        "set<#{elem}>"
      end

      def inspect
        "Types::SetOf(#{elem.inspect})"
      end

      def ==(other)
        other.is_a?(SetOf) && elem == other.elem
      end

      def hash
        [self.class, elem].hash
      end
    end

    class HashOf < Base
      attr_reader :key, :val

      def initialize(key, val)
        @key = key
        @val = val
      end

      def to_s
        "hash<#{key},#{val}>"
      end

      def inspect
        "Types::HashOf(#{key.inspect}, #{val.inspect})"
      end

      def ==(other)
        other.is_a?(HashOf) && key == other.key && val == other.val
      end

      def hash
        [self.class, key, val].hash
      end
    end

    class Optional < Base
      attr_reader :inner

      def initialize(inner)
        @inner = inner
      end

      def to_s
        "#{inner}?"
      end

      def inspect
        "Types::Optional(#{inner.inspect})"
      end

      def ==(other)
        other.is_a?(Optional) && inner == other.inner
      end

      def hash
        [self.class, inner].hash
      end
    end

    class Union < Base
      attr_reader :left, :right

      def initialize(left, right)
        @left = left
        @right = right
      end

      def to_s
        "#{left} | #{right}"
      end

      def inspect
        "Types::Union(#{left.inspect}, #{right.inspect})"
      end

      def ==(other)
        other.is_a?(Union) &&
          ((left == other.left && right == other.right) ||
           (left == other.right && right == other.left))
      end

      def hash
        [self.class, [left, right].sort_by(&:hash)].hash
      end
    end

    # Primitive type constants
    INT = Primitive.new(:int)
    FLOAT = Primitive.new(:float)
    DECIMAL = Primitive.new(:decimal)
    STRING = Primitive.new(:string)
    BOOL = Primitive.new(:bool)
    DATE = Primitive.new(:date)
    TIME = Primitive.new(:time)
    DATETIME = Primitive.new(:datetime)
    SYMBOL = Primitive.new(:symbol)
    REGEXP = Primitive.new(:regexp)
    UUID = Primitive.new(:uuid)

    # Common type unions
    NUMERIC = Union.new(INT, FLOAT)

    # Helper methods
    def self.array(elem_type)
      ArrayOf.new(elem_type)
    end

    def self.set(elem_type)
      SetOf.new(elem_type)
    end

    def self.hash(key_type, val_type)
      HashOf.new(key_type, val_type)
    end

    def self.optional(inner_type)
      Optional.new(inner_type)
    end

    # Type inference from Ruby values
    def self.infer_from_value(value)
      case value
      when Integer then INT
      when Float then FLOAT
      when String then STRING
      when TrueClass, FalseClass then BOOL
      when Symbol then SYMBOL
      when Regexp then REGEXP
      when Time then TIME
      when Array then array(Base.new) # Generic array for now
      when Hash then hash(Base.new, Base.new) # Generic hash for now
      else
        # Handle optional dependencies
        return DATE if defined?(Date) && value.is_a?(Date)
        return DATETIME if defined?(DateTime) && value.is_a?(DateTime)
        return set(Base.new) if defined?(Set) && value.is_a?(Set)

        Base.new
      end
    end

    # Type unification - find common supertype
    def self.unify(type1, type2)
      return type1 if type1 == type2
      return type1 if type2.is_a?(Base) && type2.instance_of?(Base)
      return type2 if type1.is_a?(Base) && type1.instance_of?(Base)

      # For primitives, create union
      return Union.new(type1, type2) if type1.is_a?(Primitive) && type2.is_a?(Primitive)

      # For collections of same type, unify element types
      return ArrayOf.new(unify(type1.elem, type2.elem)) if type1.is_a?(ArrayOf) && type2.is_a?(ArrayOf)

      return SetOf.new(unify(type1.elem, type2.elem)) if type1.is_a?(SetOf) && type2.is_a?(SetOf)

      return HashOf.new(unify(type1.key, type2.key), unify(type1.val, type2.val)) if type1.is_a?(HashOf) && type2.is_a?(HashOf)

      # For different types, fall back to union
      Union.new(type1, type2)
    end

    # Check if type1 is compatible with type2
    def self.compatible?(type1, type2)
      return true if type1 == type2
      return true if type2.is_a?(Base) && type2.instance_of?(Base)
      return true if type1.is_a?(Base) && type1.instance_of?(Base)

      # Optional types are compatible with their inner type
      return compatible?(type1.inner, type2) if type1.is_a?(Optional)

      return compatible?(type1, type2.inner) if type2.is_a?(Optional)

      # Union types are compatible if either side is compatible
      return compatible?(type1.left, type2) || compatible?(type1.right, type2) if type1.is_a?(Union)

      return compatible?(type1, type2.left) || compatible?(type1, type2.right) if type2.is_a?(Union)

      # Numeric compatibility
      return true if [type1, type2].all? { |t| [INT, FLOAT, DECIMAL].include?(t) }

      false
    end
  end
end

# Freeze all type instances
ObjectSpace.each_object(Kumi::Types::Base, &:freeze)
