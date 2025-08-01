# frozen_string_literal: true

module Kumi
  module Core
    module Domain
      class ViolationFormatter
        def self.format_message(field, value, domain)
          case domain
          when Range
            format_range_violation(field, value, domain)
          when Array
            format_array_violation(field, value, domain)
          when Proc
            format_proc_violation(field, value)
          else
            format_default_violation(field, value, domain)
          end
        end

        private_class_method def self.format_range_violation(field, value, range)
          if range.exclude_end?
            "Field :#{field} value #{value.inspect} is outside domain #{range.begin}...#{range.end} (exclusive)"
          else
            "Field :#{field} value #{value.inspect} is outside domain #{range.begin}..#{range.end}"
          end
        end

        private_class_method def self.format_array_violation(field, value, array)
          "Field :#{field} value #{value.inspect} is not in allowed values #{array.inspect}"
        end

        private_class_method def self.format_proc_violation(field, value)
          "Field :#{field} value #{value.inspect} does not satisfy custom domain constraint"
        end

        private_class_method def self.format_default_violation(field, value, domain)
          "Field :#{field} value #{value.inspect} violates domain constraint #{domain.inspect}"
        end
      end
    end
  end
end
