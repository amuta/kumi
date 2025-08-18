# frozen_string_literal: true

module Kumi
  module Core
    module Naming
      module BasenameNormalizer
        MAP = {
          # arithmetic legacy → canonical
          subtract: :sub, multiply: :mul, divide: :div, modulo: :mod, power: :pow,
          # comparisons
          "==": :eq, "!=": :ne, "<": :lt, "<=": :le, ">": :gt, ">=": :ge,
          greater_than: :gt, less_than: :lt, equals: :eq, not_equals: :ne,
          # logical
          "&": :and, "|": :or, "!": :not,
          # indexing / membership
          at: :get, include?: :contains,
          # common aliases
          gte: :ge, lte: :le
        }.freeze

        def self.normalize(name)
          sym = name.to_sym
          MAP.fetch(sym, sym)
        end
      end
    end
  end
end
