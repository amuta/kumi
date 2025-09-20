# frozen_string_literal: true

require "date"

module Kumi
  module Core
    module Types
      # Normalizes different type inputs to canonical forms
      class Normalizer
        # Type normalization - convert various inputs to canonical type symbols
        def self.normalize(type_input)
          case type_input
          when Symbol
            return type_input if Validator.valid_type?(type_input)

            raise ArgumentError, "Invalid type symbol: #{type_input}"
          when String
            symbol_type = type_input.to_sym
            return symbol_type if Validator.valid_type?(symbol_type)

            raise ArgumentError, "Invalid type string: #{type_input}"
          when Hash
            return type_input if Validator.valid_type?(type_input)

            raise ArgumentError, "Invalid type hash: #{type_input}"
          when Class
            # Handle Ruby class inputs
            case type_input.name
            when "NilClass" then :null
            when "Integer" then :integer
            when "String" then :string
            when "Float" then :float
            when "TrueClass", "FalseClass" then :boolean
            when "Array" then raise ArgumentError, "Use array(:type) helper for array types"
            when "Hash" then raise ArgumentError, "Use hash(:key_type, :value_type) helper for hash types"
            else
              raise ArgumentError, "Unsupported class type: #{type_input}"
            end
          else
            case type_input
            when Integer, Float, Numeric
              raise ArgumentError, "Type must be a symbol, got #{type_input} (#{type_input.class})"
            else
              raise ArgumentError, "Invalid type input: #{type_input} (#{type_input.class})"
            end
          end
        end

        # Legacy compatibility - coerce old constants to symbols
        def self.coerce(type_input)
          # Handle legacy constant usage
          return type_input if type_input.is_a?(Symbol) && Validator.valid_type?(type_input)

          # Handle legacy constant objects
          case type_input
          when STRING then :string
          when INT then :integer
          when FLOAT, NUMERIC then :float # Both FLOAT and NUMERIC map to :float
          when BOOL then :boolean
          when ANY then :any
          when SYMBOL then :symbol
          when REGEXP then :regexp
          when TIME then :time
          when DATE then :date
          when DATETIME then :datetime
          else
            normalize(type_input)
          end
        end
      end
    end
  end
end
