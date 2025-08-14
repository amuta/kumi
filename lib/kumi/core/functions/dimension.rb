# frozen_string_literal: true

require_relative "errors"

module Kumi
  module Core
    module Functions
      # Represents a single dimension in a signature with NEP 20 support.
      #
      # A dimension can be:
      # - Named dimension (symbol): :i, :j, :n
      # - Fixed-size dimension (integer): 2, 3, 10
      # - With modifiers:
      #   - flexible (?): can be omitted if not present in all operands
      #   - broadcastable (|1): can broadcast against size-1 dimensions
      #
      # Examples:
      #   Dimension.new(:i)           # named dimension 'i'
      #   Dimension.new(3)            # fixed-size dimension of size 3
      #   Dimension.new(:n, flexible: true)      # dimension 'n' that can be omitted
      #   Dimension.new(:i, broadcastable: true) # dimension 'i' that can broadcast
      class Dimension
        attr_reader :name, :flexible, :broadcastable

        def initialize(name, flexible: false, broadcastable: false)
          @name = name
          @flexible = flexible
          @broadcastable = broadcastable

          validate!
          freeze
        end

        def fixed_size?
          @name.is_a?(Integer)
        end

        def named?
          @name.is_a?(Symbol)
        end

        def flexible?
          @flexible
        end

        def broadcastable?
          @broadcastable
        end

        def size
          fixed_size? ? @name : nil
        end

        def ==(other)
          other.is_a?(Dimension) &&
            name == other.name &&
            flexible == other.flexible &&
            broadcastable == other.broadcastable
        end

        def eql?(other)
          self == other
        end

        def hash
          [name, flexible, broadcastable].hash
        end

        def to_s
          str = name.to_s
          str += "?" if flexible?
          str += "|1" if broadcastable?
          str
        end

        def inspect
          "#<Dimension #{self}>"
        end

        private

        def validate!
          unless name.is_a?(Symbol) || name.is_a?(Integer)
            raise SignatureError, "dimension name must be a symbol or integer, got: #{name.inspect}"
          end

          raise SignatureError, "fixed-size dimension must be positive, got: #{name}" if name.is_a?(Integer) && name <= 0

          raise SignatureError, "dimension cannot be both flexible and broadcastable" if flexible? && broadcastable?

          return unless fixed_size? && flexible?

          raise SignatureError, "fixed-size dimension cannot be flexible"
        end
      end
    end
  end
end
