# frozen_string_literal: true

require "bigdecimal"

module Kumi
  module Dev
    module Golden
      # Normalizes values for test comparisons, handling decimal precision
      class ValueNormalizer
        def self.normalize(value, language: :ruby)
          case value
          when Hash
            value.transform_values { |v| normalize(v, language: language) }
          when Array
            value.map { |v| normalize(v, language: language) }
          when String
            # Try to parse as decimal if it looks like one
            if decimal_string?(value)
              language == :ruby ? BigDecimal(value) : value
            else
              value
            end
          else
            value
          end
        end

        def self.values_equal?(actual, expected, language: :ruby)
          norm_actual = normalize(actual, language: language)
          norm_expected = normalize(expected, language: language)

          compare_values(norm_actual, norm_expected, language: language)
        end

        def self.decimal_string?(str)
          # Match decimal number strings like "10.50", "123", "-45.67"
          str.match?(/\A-?\d+(\.\d+)?\z/)
        end

        def self.compare_values(actual, expected, language:)
          # Handle decimal comparisons with tolerance for floating-point errors
          case [actual, expected]
          in [Array, Array]
            actual.length == expected.length &&
              actual.zip(expected).all? { |a, e| compare_values(a, e, language: language) }
          in [Hash, Hash]
            actual.keys == expected.keys &&
              actual.all? { |k, v| compare_values(v, expected[k], language: language) }
          in [BigDecimal, BigDecimal]
            actual == expected
          in [BigDecimal, (Integer | Float)]
            BigDecimal(actual.to_s) == BigDecimal(expected.to_s)
          in [(Integer | Float), BigDecimal]
            BigDecimal(actual.to_s) == BigDecimal(expected.to_s)
          in [(Integer | Float), String] | [String, (Integer | Float)]
            # Compare number with decimal string (e.g., JavaScript number vs expected string)
            actual_bd = BigDecimal(actual.to_s)
            expected_bd = BigDecimal(expected.to_s)
            # Allow small floating-point differences (within 1e-10)
            (actual_bd - expected_bd).abs < BigDecimal("1e-10")
          in [String, String]
            # Both strings - try to parse as decimals and compare
            begin
              actual_bd = BigDecimal(actual)
              expected_bd = BigDecimal(expected)
              (actual_bd - expected_bd).abs < BigDecimal("1e-10")
            rescue ArgumentError
              # If not valid decimals, compare as strings
              actual == expected
            end
          else
            actual == expected
          end
        end
      end
    end
  end
end
