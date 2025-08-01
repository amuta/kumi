# frozen_string_literal: true

module Kumi::Core
  module Domain
    class EnumAnalyzer
      def self.analyze(enum)
        {
          type: :enumeration,
          values: enum,
          size: enum.size,
          sample_values: generate_samples(enum),
          invalid_samples: generate_invalid_samples(enum)
        }
      end

      def self.generate_samples(enum)
        enum.sample([enum.size, 3].min)
      end

      def self.generate_invalid_samples(enum)
        case enum.first
        when String
          generate_string_invalid_samples(enum)
        when Integer
          generate_integer_invalid_samples(enum)
        when Symbol
          generate_symbol_invalid_samples(enum)
        else
          generate_default_invalid_samples
        end
      end

      private_class_method def self.generate_string_invalid_samples(enum)
        candidates = ["invalid_string", "", "not_in_list"]
        candidates.reject { |v| enum.include?(v) }
      end

      private_class_method def self.generate_integer_invalid_samples(enum)
        candidates = [-999, 0, 999]
        candidates.reject { |v| enum.include?(v) }
      end

      private_class_method def self.generate_symbol_invalid_samples(enum)
        candidates = %i[invalid_symbol not_in_list]
        candidates.reject { |v| enum.include?(v) }
      end

      private_class_method def self.generate_default_invalid_samples
        [nil, "invalid", -1]
      end
    end
  end
end
