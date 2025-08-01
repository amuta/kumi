# frozen_string_literal: true

require "date"

module Kumi
  module Core
    module Types
      # Infers types from Ruby values
      class Inference
        def self.infer_from_value(value)
          case value
          when String then :string
          when Integer then :integer
          when Float then :float
          when TrueClass, FalseClass then :boolean
          when Symbol then :symbol
          when Regexp then :regexp
          when Time then :time
          when DateTime then :datetime
          when Date then :date
          when Array
            return Kumi::Core::Types.array(:any) if value.empty?

            # Infer element type from first element (simple heuristic)
            first_elem_type = infer_from_value(value.first)
            Kumi::Core::Types.array(first_elem_type)
          when Hash
            return Kumi::Core::Types.hash(:any, :any) if value.empty?

            # Infer key/value types from first pair (simple heuristic)
            first_key, first_value = value.first
            key_type = infer_from_value(first_key)
            value_type = infer_from_value(first_value)
            Kumi::Core::Types.hash(key_type, value_type)
          else
            :any
          end
        end
      end
    end
  end
end
