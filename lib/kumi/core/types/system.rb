# frozen_string_literal: true

module Kumi
  module Core
    module Types
      # The single interface for type operations: promotion, unification,
      # element extraction, and constraint compatibility. All policy lives in the
      # Profile it holds, so behavior is configurable per target / per schema
      # hint rather than hardcoded.
      #
      #   ts = Types::System.default
      #   ts.promote(decimal, integer)            # => decimal
      #   ts.compatible?("numeric", float)        # => true
      #   ts.element_of(array_of_int)             # => integer
      class System
        attr_reader :profile

        def initialize(profile = Profile.default)
          @profile = profile
        end

        def self.default
          @default ||= new(Profile.default)
        end

        def self.for_target(target)
          new(Profile.for_target(target))
        end

        # Promote a set of types to the one that wins the promotion lattice.
        # Numeric kinds follow the profile's lattice (decimal > float > integer);
        # if no operand is in the lattice, the first type is returned unchanged.
        def promote(*types)
          types = types.flatten.compact.uniq
          return ScalarType.new(:any) if types.empty?
          return types.first if types.size == 1

          kinds = types.filter_map { |t| t.kind if t.is_a?(ScalarType) }
          winner = @profile.promote_kind(kinds)
          winner ? ScalarType.new(winner) : types.first
        end

        # The common type of two types: identical types unify to themselves,
        # otherwise they promote.
        def unify(left, right)
          left == right ? left : promote(left, right)
        end

        # The element type of a collection. Arrays yield their element type;
        # tuples promote their elements to a common type; scalars are returned
        # as-is.
        def element_of(type)
          case type
          when ArrayType then type.element_type
          when TupleType then promote(*type.element_types)
          else type
          end
        end

        # Does a type satisfy a parameter's dtype constraint? A nil constraint
        # accepts anything. The constraint is either a category name (expands to
        # a set of kinds) or a single kind / composite tag (array, tuple).
        def compatible?(constraint, type)
          return true if constraint.nil?

          name = constraint.to_s
          return category_match?(name, type) if @profile.category?(name)

          case name
          when "array" then type.is_a?(ArrayType)
          when "tuple" then type.is_a?(TupleType)
          else
            kind = name.to_sym
            return true unless Registry.kind?(kind)

            type.is_a?(ScalarType) && type.kind == kind
          end
        end

        def category_match?(name, type)
          type.is_a?(ScalarType) && @profile.category_kinds(name).include?(type.kind)
        end

        # How well a type matches a constraint, for overload ranking: 0 = no
        # match, 1 = matches an unconstrained parameter, 2 = matches an explicit
        # constraint. Higher beats lower when choosing among overloads.
        def match_score(constraint, type)
          return 0 unless compatible?(constraint, type)
          return 1 if constraint.nil?

          2
        end
      end
    end
  end
end
