# frozen_string_literal: true

module Kumi
  module Input
    class ViolationCreator
      def self.create_type_violation(field, value, expected_type)
        {
          type: :type_violation,
          field: field,
          value: value,
          expected_type: expected_type,
          actual_type: TypeMatcher.infer_type(value),
          message: format_type_violation_message(field, value, expected_type)
        }
      end

      def self.create_domain_violation(field, value, domain)
        {
          type: :domain_violation,
          field: field,
          value: value,
          domain: domain,
          message: Kumi::Domain::ViolationFormatter.format_message(field, value, domain)
        }
      end

      def self.create_missing_field_violation(field, expected_type)
        {
          type: :missing_field_violation,
          field: field,
          expected_type: expected_type,
          message: format_missing_field_message(field, expected_type)
        }
      end

      private_class_method def self.format_type_violation_message(field, value, expected_type)
        actual_type = TypeMatcher.infer_type(value)
        expected_formatted = TypeMatcher.format_type(expected_type)
        actual_formatted = TypeMatcher.format_type(actual_type)

        "Field :#{field} expected #{expected_formatted}, got #{value.inspect} of type #{actual_formatted}"
      end

      private_class_method def self.format_missing_field_message(field, expected_type)
        expected_formatted = TypeMatcher.format_type(expected_type)
        "Missing required field :#{field} of type #{expected_formatted}"
      end
    end
  end
end
