# frozen_string_literal: true

module Kumi
  module Core
    module Types
      # Builds complex type structures
      class Builder
        def self.array(elem_type)
          raise ArgumentError, "Invalid array element type: #{elem_type}" unless Validator.valid_type?(elem_type)

          "array<#{elem_type}>"
        end

        def self.hash(key_type, val_type)
          raise ArgumentError, "Invalid hash key type: #{key_type}" unless Validator.valid_type?(key_type)
          raise ArgumentError, "Invalid hash value type: #{val_type}" unless Validator.valid_type?(val_type)

          :hash
        end
      end
    end
  end
end
