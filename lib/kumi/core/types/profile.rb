# frozen_string_literal: true

module Kumi
  module Core
    module Types
      # A Profile is the configurable policy of the type system: the tables that
      # decide how scalar kinds promote, which kinds belong to which constraint
      # category, and whether a kind satisfies a parameter constraint.
      #
      # There is one default Profile today, but every target backend gets its own
      # (currently a copy of the default). This is the seam where per-target
      # differences and, later, schema configuration hints override behavior —
      # so type policy is never a single hardcoded global.
      #
      #   Profile.default              # the shipped global behavior
      #   Profile.for_target(:ruby)    # ruby backend's policy
      #   default.with(promotion: ...) # derive a variant (for hints/targets)
      class Profile
        # Numeric promotion lattice, widest first. promote(a, b) returns the kind
        # that appears earliest here among the operands. decimal is the widest
        # (exact, money-grade), then float, then integer.
        DEFAULT_PROMOTION = %i[decimal float integer].freeze

        # Named constraint categories: a parameter whose dtype is one of these
        # accepts any kind in the list. These are the reusable type constraints
        # referenced from function definitions (e.g. dtype: numeric).
        DEFAULT_CATEGORIES = {
          numeric: %i[integer float decimal],
          comparable: %i[integer float decimal string],
          orderable: %i[integer float decimal string],
          boolean: %i[boolean],
          stringable: %i[string]
        }.freeze

        attr_reader :name, :promotion, :categories

        def initialize(name:, promotion: DEFAULT_PROMOTION, categories: DEFAULT_CATEGORIES)
          @name = name
          @promotion = promotion.freeze
          @categories = categories.freeze
          @promotion_rank = promotion.each_with_index.to_h.freeze
        end

        # The default, shipped policy.
        def self.default
          @default ||= new(name: :default)
        end

        # Per-target policy. Starts as the default; this is where a backend
        # diverges from the global behavior when it needs to.
        def self.for_target(target)
          (@by_target ||= {})[target.to_sym] ||= new(name: target.to_sym)
        end

        # Derive a variant overriding individual tables. Used to layer target
        # and (eventually) schema-hint overrides on top of a base profile.
        def with(promotion: @promotion, categories: @categories, name: @name)
          self.class.new(name: name, promotion: promotion, categories: categories)
        end

        # Among the given scalar kinds, the one that wins promotion (earliest in
        # the lattice). Returns nil if none of them are in the lattice, letting
        # the caller fall back (e.g. to the first operand for non-numeric types).
        def promote_kind(kinds)
          ranked = kinds.select { |k| @promotion_rank.key?(k) }
          return nil if ranked.empty?

          ranked.min_by { |k| @promotion_rank.fetch(k) }
        end

        def category?(name)
          @categories.key?(name.to_sym)
        end

        # The kinds a category constraint expands to, or nil if not a category.
        def category_kinds(name)
          @categories[name.to_sym]
        end
      end
    end
  end
end
