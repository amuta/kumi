# frozen_string_literal: true

module Kumi
  module Core
    module Types
      # Base class for all type objects
      class Type
        def scalar?
          is_a?(ScalarType)
        end

        def array?
          is_a?(ArrayType)
        end

        def tuple?
          is_a?(TupleType)
        end
      end

      # Represents scalar types: string, integer, float, boolean, hash
      class ScalarType < Type
        attr_reader :kind

        def initialize(kind)
          @kind = kind
        end

        def to_s
          @kind.to_s
        end

        def inspect
          "#<ScalarType:#{@kind}>"
        end

        def ==(other)
          return false unless other.is_a?(ScalarType)

          @kind == other.kind
        end

        def eql?(other)
          self == other
        end

        def hash
          [@kind].hash
        end
      end

      # Represents array types with an element type
      class ArrayType < Type
        attr_reader :element_type

        def initialize(element_type)
          @element_type = element_type
        end

        def to_s
          "array<#{@element_type}>"
        end

        def inspect
          "#<ArrayType:#{self}>"
        end

        def ==(other)
          return false unless other.is_a?(ArrayType)

          @element_type == other.element_type
        end

        def eql?(other)
          self == other
        end

        def hash
          [@element_type].hash
        end
      end

      # Represents tuple types with a list of element types
      class TupleType < Type
        attr_reader :element_types

        def initialize(element_types)
          @element_types = element_types
        end

        def to_s
          "tuple<#{@element_types.join(', ')}>"
        end

        def inspect
          "#<TupleType:#{self}>"
        end

        def ==(other)
          return false unless other.is_a?(TupleType)

          @element_types == other.element_types
        end

        def eql?(other)
          self == other
        end

        def hash
          @element_types.hash
        end
      end

      # Namespace module for consistency with autoloader
      module ValueObjects
      end
    end
  end
end
