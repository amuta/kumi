# frozen_string_literal: true

module Kumi
  module Core
    module Input
      class Validator
        def self.validate_context(context, input_meta)
          violations = []

          context.each do |field, value|
            meta = input_meta[field]
            next unless meta

            # Type validation first
            if should_validate_type?(meta) && !TypeMatcher.matches?(value, meta[:type])
              violations << ViolationCreator.create_type_violation(field, value, meta[:type])
              next # Skip domain validation if type is wrong
            end

            # Domain validation second (only if type is correct)
            if should_validate_domain?(meta) && !Domain::Validator.validate_field(field, value, meta[:domain])
              violations << ViolationCreator.create_domain_violation(field, value, meta[:domain])
            end
          end

          violations
        end

        def self.type_matches?(value, declared_type)
          TypeMatcher.matches?(value, declared_type)
        end

        def self.infer_type(value)
          TypeMatcher.infer_type(value)
        end

        def self.format_type(type)
          TypeMatcher.format_type(type)
        end

        private_class_method def self.should_validate_type?(meta)
          meta[:type] && meta[:type] != :any
        end

        private_class_method def self.should_validate_domain?(meta)
          meta[:domain]
        end
      end
    end
  end
end
