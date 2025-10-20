# frozen_string_literal: true

require 'bigdecimal'

module Kumi
  module Core
    module Input
      class TypeMatcher
        def self.matches?(value, declared_type)
          case declared_type
          when :integer
            value.is_a?(Integer)
          when :float
            value.is_a?(Float) || value.is_a?(Integer) # Allow integer for float
          when :decimal
            value.is_a?(BigDecimal) || value.is_a?(Float) || value.is_a?(Integer)
          when :string
            value.is_a?(String)
          when :boolean
            value.is_a?(TrueClass) || value.is_a?(FalseClass)
          when :symbol
            value.is_a?(Symbol)
          when :array
            # Simple :array type - just check if it's an Array
            value.is_a?(Array)
          when :any
            true
          else
            # Handle complex types (arrays, hashes)
            handle_complex_type(value, declared_type)
          end
        end

        def self.infer_type(value)
          case value
          when Integer then :integer
          when Float then :float
          when String then :string
          when TrueClass, FalseClass then :boolean
          when Symbol then :symbol
          when Array then { array: :mixed }
          when Hash then { hash: %i[mixed mixed] }
          else
            return :decimal if value.is_a?(BigDecimal)

            :unknown
          end
        end

        def self.format_type(type)
          case type
          when Symbol
            type.to_s
          when Hash
            format_complex_type(type)
          else
            type.inspect
          end
        end

        private_class_method def self.handle_complex_type(value, declared_type)
          return false unless declared_type.is_a?(Hash)

          if declared_type.key?(:array)
            handle_array_type(value, declared_type[:array])
          elsif declared_type.key?(:hash)
            handle_hash_type(value, declared_type[:hash])
          else
            false
          end
        end

        private_class_method def self.handle_array_type(value, element_type)
          return false unless value.is_a?(Array)
          return true if element_type == :any

          value.all? { |elem| matches?(elem, element_type) }
        end

        private_class_method def self.handle_hash_type(value, hash_spec)
          return false unless value.is_a?(Hash)

          key_type, value_type = hash_spec
          return true if key_type == :any && value_type == :any

          value.all? do |k, v|
            matches?(k, key_type) && matches?(v, value_type)
          end
        end

        private_class_method def self.format_complex_type(type)
          if type.key?(:array)
            "array(#{format_type(type[:array])})"
          elsif type.key?(:hash)
            key_type, value_type = type[:hash]
            "hash(#{format_type(key_type)}, #{format_type(value_type)})"
          else
            type.inspect
          end
        end
      end
    end
  end
end
