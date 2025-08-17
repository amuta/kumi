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
        
        # RegistryV2 dtype expression to type mapping
        DTYPE_TO_TYPE = {
          # Boolean types
          "bool" => :boolean,
          
          # Numeric promotion types
          "promote(T,U)" => :float,
          "promote_float(T,U)" => :float,
          "promote(T)" => :float,
          
          # Generic type parameters
          "T" => :float, # Most aggregates work on numeric data
          "A" => :any,   # Generic element type (e.g., for array indexing)
          
          # Explicit types
          "int" => :integer,
          "float" => :float,
          "string" => :string,
          "str" => :string
        }.freeze
        
        # Infer types from RegistryV2 dtype expressions
        def self.infer_from_dtype(dtype_expr)
          dtype_str = dtype_expr.to_s
          
          # Check exact match first
          return DTYPE_TO_TYPE[dtype_str] if DTYPE_TO_TYPE.key?(dtype_str)
          
          # If not found, raise an error to help us identify missing mappings
          raise "Unknown RegistryV2 dtype expression: '#{dtype_str}'. Please add mapping to DTYPE_TO_TYPE."
        end
      end
    end
  end
end
