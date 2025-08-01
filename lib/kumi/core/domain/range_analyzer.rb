# frozen_string_literal: true

module Kumi
  module Core
    module Domain
      class RangeAnalyzer
        def self.analyze(range)
          {
            type: :range,
            min: range.begin,
            max: range.end,
            exclusive_end: range.exclude_end?,
            size: calculate_size(range),
            sample_values: generate_samples(range),
            boundary_values: [range.begin, range.end],
            invalid_samples: generate_invalid_samples(range)
          }
        end

        def self.calculate_size(range)
          return :infinite if range.begin.nil? || range.end.nil?
          return :large if range.end - range.begin > 1000

          if integer_range?(range)
            range.exclude_end? ? range.end - range.begin : range.end - range.begin + 1
          else
            :continuous
          end
        end

        def self.generate_samples(range)
          samples = [range.begin]

          samples << calculate_midpoint(range) if numeric_range?(range)

          samples << calculate_endpoint(range)
          samples.uniq
        end

        def self.generate_invalid_samples(range)
          invalid = []

          invalid << calculate_before_start(range) if range.begin.is_a?(Numeric)

          invalid << calculate_after_end(range) if range.end.is_a?(Numeric)

          invalid
        end

        private_class_method def self.integer_range?(range)
          range.begin.is_a?(Integer) && range.end.is_a?(Integer)
        end

        private_class_method def self.numeric_range?(range)
          range.begin.is_a?(Numeric) && range.end.is_a?(Numeric)
        end

        private_class_method def self.calculate_midpoint(range)
          mid = (range.begin + range.end) / 2.0
          range.begin.is_a?(Integer) ? mid.round : mid
        end

        private_class_method def self.calculate_endpoint(range)
          if range.exclude_end?
            range.end - (range.begin.is_a?(Integer) ? 1 : 0.1)
          else
            range.end
          end
        end

        private_class_method def self.calculate_before_start(range)
          range.begin - (range.begin.is_a?(Integer) ? 1 : 0.1)
        end

        private_class_method def self.calculate_after_end(range)
          if range.exclude_end?
            range.end
          else
            range.end + (range.end.is_a?(Integer) ? 1 : 0.1)
          end
        end
      end
    end
  end
end
