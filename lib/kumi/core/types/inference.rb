# frozen_string_literal: true

require "date"

module Kumi
  module Core
    module Types
      # Infers types from Ruby values
      class Inference
        def self.infer_from_value(value)
          case value
          when String
            Kumi::Core::Types.scalar(:string)
          when Integer
            Kumi::Core::Types.scalar(:integer)
          when Float
            Kumi::Core::Types.scalar(:float)
          when TrueClass, FalseClass
            Kumi::Core::Types.scalar(:boolean)
          when Symbol
            Kumi::Core::Types.scalar(:symbol)
          when Regexp
            Kumi::Core::Types.scalar(:regexp)
          when Time
            Kumi::Core::Types.scalar(:time)
          when DateTime
            Kumi::Core::Types.scalar(:datetime)
          when Date
            Kumi::Core::Types.scalar(:date)
          when Array
            if value.empty?
              Kumi::Core::Types.array(Kumi::Core::Types.scalar(:any))
            else
              # Infer element type from first element (simple heuristic)
              elem_type = infer_from_value(value.first)
              Kumi::Core::Types.array(elem_type)
            end
          when Hash
            # Kumi treats hash as scalar, not key/value pair type
            # So we just return scalar(:hash) regardless of contents
            Kumi::Core::Types.scalar(:hash)
          else
            Kumi::Core::Types.scalar(:any)
          end
        end
      end
    end
  end
end
