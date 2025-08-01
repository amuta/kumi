# frozen_string_literal: true

module Kumi
  module Core
    module Domain
      class Validator
        def self.validate_field(_field_name, value, domain)
          return true if domain.nil?

          case domain
          when Range
            domain.cover?(value)
          when Array
            domain.include?(value)
          when Proc
            domain.call(value)
          else
            true
          end
        end

        def self.validate_context(context, input_meta)
          violations = []

          context.each do |field, value|
            meta = input_meta[field]
            next unless meta&.dig(:domain)

            violations << create_violation(field, value, meta[:domain]) unless validate_field(field, value, meta[:domain])
          end

          violations
        end

        def self.extract_domain_metadata(input_meta)
          metadata = {}

          input_meta.each do |field, meta|
            domain = meta[:domain]
            next unless domain

            metadata[field] = analyze_domain(field, domain)
          end

          metadata
        end

        def self.create_violation(field, value, domain)
          {
            field: field,
            value: value,
            domain: domain,
            message: ViolationFormatter.format_message(field, value, domain)
          }
        end

        def self.analyze_domain(_field, domain)
          case domain
          when Range
            RangeAnalyzer.analyze(domain)
          when Array
            EnumAnalyzer.analyze(domain)
          when Proc
            {
              type: :custom,
              description: "Custom constraint function",
              sample_values: [],
              invalid_samples: []
            }
          else
            {
              type: :unknown,
              constraint: domain,
              sample_values: [],
              invalid_samples: []
            }
          end
        end
      end
    end
  end
end
