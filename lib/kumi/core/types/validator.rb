# frozen_string_literal: true

module Kumi
  module Core
    module Types
      # Validates type definitions and structures
      class Validator
        VALID_TYPES = %i[string integer float boolean any symbol regexp time date datetime array hash null].freeze

        # Validate scalar kinds (no :array or :hash)
        VALID_KINDS = %i[string integer float boolean any symbol regexp time date datetime null].freeze

        def self.valid_kind?(kind)
          VALID_KINDS.include?(kind)
        end

        def self.valid_type?(type)
          # Support Type objects
          case type
          when ScalarType
            valid_kind?(type.kind)
          when ArrayType, TupleType
            true  # If constructed, it's valid
          when Symbol
            valid_kind?(type)
          else
            false
          end
        end
      end
    end
  end
end
