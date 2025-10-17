# frozen_string_literal: true

require "date"

module Kumi
  module Core
    module Types
      # Normalizes different type inputs to canonical Type objects
      class Normalizer
        # Type normalization - convert various inputs to Type objects
        def self.normalize(type_input)
          case type_input
          when Type
            # Already a Type object, return as-is
            type_input
          when Symbol
            if Validator.valid_kind?(type_input)
              Kumi::Core::Types.scalar(type_input)
            else
              raise ArgumentError, "Invalid type symbol: #{type_input}"
            end
          when String
            symbol_type = type_input.to_sym
            if Validator.valid_kind?(symbol_type)
              Kumi::Core::Types.scalar(symbol_type)
            else
              raise ArgumentError, "Invalid type string: #{type_input}"
            end
          when Hash
            raise ArgumentError, "Hash-based types no longer supported, use Type objects instead"
          when Class
            # Handle Ruby class inputs
            kind = case type_input.name
                   when "NilClass" then :null
                   when "Integer" then :integer
                   when "String" then :string
                   when "Float" then :float
                   when "Symbol" then :symbol
                   when "TrueClass", "FalseClass" then :boolean
                   when "Array" then raise ArgumentError, "Use array(:type) helper for array types"
                   when "Hash" then raise ArgumentError, "Use scalar(:hash) for hash type"
                   else
                     raise ArgumentError, "Unsupported class type: #{type_input}"
                   end
            Kumi::Core::Types.scalar(kind)
          else
            case type_input
            when Integer, Float, Numeric
              raise ArgumentError, "Type must be a symbol, got #{type_input} (#{type_input.class})"
            else
              raise ArgumentError, "Invalid type input: #{type_input} (#{type_input.class})"
            end
          end
        end

        # Legacy compatibility - coerce old constants to Type objects
        def self.coerce(type_input)
          # Handle legacy constant usage
          if type_input.is_a?(Symbol) && Validator.valid_kind?(type_input)
            return Kumi::Core::Types.scalar(type_input)
          end

          # Handle Type objects
          if type_input.is_a?(Type)
            return type_input
          end

          # Handle legacy constant objects
          kind = case type_input
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
                   # Fall through to normalize
                   return normalize(type_input)
                 end
          Kumi::Core::Types.scalar(kind)
        end
      end
    end
  end
end
