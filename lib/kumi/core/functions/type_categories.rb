# frozen_string_literal: true

module Kumi
  module Core
    module Functions
      # Type categories define reusable type constraints
      # Instead of hardcoding type checks scattered throughout the codebase,
      # we define categories once and reference them in function definitions
      class TypeCategories
        # Define type categories as unions of scalar kinds
        CATEGORIES = {
          numeric: [:integer, :float, :decimal],
          comparable: [:integer, :float, :decimal, :string],
          boolean: [:boolean],
          stringable: [:string],
          orderable: [:integer, :float, :decimal, :string]
        }.freeze

        def self.expand(dtype_constraint)
          return dtype_constraint unless dtype_constraint.is_a?(String)

          category = dtype_constraint.to_sym
          CATEGORIES[category] || dtype_constraint
        end

        def self.includes?(dtype_constraint, kind)
          kinds = expand(dtype_constraint)
          return kinds.include?(kind) if kinds.is_a?(Array)

          # Fall back to string comparison for uncategorized constraints
          kinds == kind.to_s
        end

        def self.category?(name)
          CATEGORIES.key?(name.to_sym)
        end

        def self.categories
          CATEGORIES
        end
      end
    end
  end
end
