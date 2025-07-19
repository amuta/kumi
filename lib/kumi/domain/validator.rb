# frozen_string_literal: true

module Kumi
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
          message: format_violation_message(field, value, domain)
        }
      end

      def self.analyze_domain(_field, domain)
        case domain
        when Range
          {
            type: :range,
            min: domain.begin,
            max: domain.end,
            exclusive_end: domain.exclude_end?,
            size: calculate_range_size(domain),
            sample_values: generate_range_samples(domain),
            boundary_values: [domain.begin, domain.end],
            invalid_samples: generate_invalid_range_samples(domain)
          }
        when Array
          {
            type: :enumeration,
            values: domain,
            size: domain.size,
            sample_values: domain.sample([domain.size, 3].min),
            invalid_samples: generate_invalid_enum_samples(domain)
          }
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

      def self.calculate_range_size(range)
        return :infinite if range.begin.nil? || range.end.nil?
        return :large if range.end - range.begin > 1000

        if range.begin.is_a?(Integer) && range.end.is_a?(Integer)
          range.exclude_end? ? range.end - range.begin : range.end - range.begin + 1
        else
          :continuous
        end
      end

      def self.generate_range_samples(range)
        samples = [range.begin]

        if range.begin.is_a?(Numeric) && range.end.is_a?(Numeric)
          mid = (range.begin + range.end) / 2.0
          samples << (range.begin.is_a?(Integer) ? mid.round : mid)
        end

        samples << if range.exclude_end?
                     (range.end - (range.begin.is_a?(Integer) ? 1 : 0.1))
                   else
                     range.end
                   end

        samples.uniq
      end

      def self.generate_invalid_range_samples(range)
        invalid = []

        if range.begin.is_a?(Numeric)
          invalid << (range.begin - (range.begin.is_a?(Integer) ? 1 : 0.1))
        end

        if range.end.is_a?(Numeric)
          invalid << if range.exclude_end?
                       range.end
                     else
                       (range.end + (range.end.is_a?(Integer) ? 1 : 0.1))
                     end
        end

        invalid
      end

      def self.generate_invalid_enum_samples(enum)
        case enum.first
        when String
          ["invalid_string", "", "not_in_list"]
        when Integer
          [-999, 0, 999].reject { |v| enum.include?(v) }
        when Symbol
          %i[invalid_symbol not_in_list].reject { |v| enum.include?(v) }
        else
          [nil, "invalid", -1]
        end
      end

      def self.format_violation_message(field, value, domain)
        case domain
        when Range
          if domain.exclude_end?
            "Field :#{field} value #{value.inspect} is outside domain #{domain.begin}...#{domain.end} (exclusive)"
          else
            "Field :#{field} value #{value.inspect} is outside domain #{domain.begin}..#{domain.end}"
          end
        when Array
          "Field :#{field} value #{value.inspect} is not in allowed values #{domain.inspect}"
        when Proc
          "Field :#{field} value #{value.inspect} does not satisfy custom domain constraint"
        else
          "Field :#{field} value #{value.inspect} violates domain constraint #{domain.inspect}"
        end
      end
    end
  end
end
