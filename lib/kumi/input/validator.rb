# frozen_string_literal: true

module Kumi
  module Input
    class Validator
      def self.validate_context(context, input_meta)
        violations = []

        context.each do |field, value|
          meta = input_meta[field]
          next unless meta

          # Type validation first
          if meta[:type] && meta[:type] != :any && !type_matches?(value, meta[:type])
            violations << create_type_violation(field, value, meta[:type])
            next # Skip domain validation if type is wrong
          end

          # Domain validation second (only if type is correct)
          if meta[:domain] && !Domain::Validator.validate_field(field, value, meta[:domain])
            violations << create_domain_violation(field, value, meta[:domain])
          end
        end

        violations
      end

      def self.type_matches?(value, declared_type)
        case declared_type
        when :integer
          value.is_a?(Integer)
        when :float
          value.is_a?(Float) || value.is_a?(Integer) # Allow integer for float
        when :string
          value.is_a?(String)
        when :boolean
          value.is_a?(TrueClass) || value.is_a?(FalseClass)
        when :symbol
          value.is_a?(Symbol)
        when :any
          true
        else
          # Handle complex types (arrays, hashes)
          handle_complex_type(value, declared_type)
        end
      end

      def self.handle_complex_type(value, declared_type)
        case declared_type
        when Hash
          if declared_type.key?(:array)
            return false unless value.is_a?(Array)

            element_type = declared_type[:array]
            return true if element_type == :any

            value.all? { |elem| type_matches?(elem, element_type) }
          elsif declared_type.key?(:hash)
            return false unless value.is_a?(Hash)

            key_type, value_type = declared_type[:hash]
            return true if key_type == :any && value_type == :any

            value.all? do |k, v|
              type_matches?(k, key_type) && type_matches?(v, value_type)
            end
          else
            false
          end
        else
          false
        end
      end

      def self.create_type_violation(field, value, expected_type)
        {
          type: :type_violation,
          field: field,
          value: value,
          expected_type: expected_type,
          actual_type: infer_type(value),
          message: format_type_violation_message(field, value, expected_type)
        }
      end

      def self.create_domain_violation(field, value, domain)
        {
          type: :domain_violation,
          field: field,
          value: value,
          domain: domain,
          message: Domain::Validator.send(:format_violation_message, field, value, domain)
        }
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
        else :unknown
        end
      end

      def self.format_type_violation_message(field, value, expected_type)
        actual_type = infer_type(value)
        "Field :#{field} expected #{format_type(expected_type)}, got #{value.inspect} of type #{format_type(actual_type)}"
      end

      def self.format_type(type)
        case type
        when Symbol
          type.to_s
        when Hash
          if type.key?(:array)
            "array(#{format_type(type[:array])})"
          elsif type.key?(:hash)
            key_type, value_type = type[:hash]
            "hash(#{format_type(key_type)}, #{format_type(value_type)})"
          else
            type.inspect
          end
        else
          type.inspect
        end
      end
    end
  end
end
