# frozen_string_literal: true

require "set"

module Kumi
  module Core
    module Types
      # The single source of truth for which scalar kinds exist and how the
      # canonical string form of a type is parsed back into a Type object.
      #
      # A "kind" is a scalar leaf (:integer, :decimal, :string, ...). Composite
      # types (array, tuple) are structures over kinds and are not themselves
      # kinds. KINDS is the authoritative list; everything else that needs to
      # enumerate or validate scalar types reads from here.
      module Registry
        module_function

        # Authoritative scalar kinds. Adding a kind here is the only place a new
        # leaf type needs to be declared.
        KINDS = %i[
          string integer float decimal boolean
          symbol regexp time date datetime
          hash any null pair
        ].freeze

        KIND_SET = KINDS.to_set.freeze

        def kind?(name)
          KIND_SET.include?(name)
        end

        # True for a Type object or a bare kind symbol that names a real type.
        def valid?(type)
          case type
          when ScalarType then kind?(type.kind)
          when ArrayType, TupleType then true
          when Symbol then kind?(type)
          else false
          end
        end

        # Parse the canonical string form back into a Type object. Inverse of
        # Type#to_s:
        #
        #   "decimal"               -> ScalarType(:decimal)
        #   "array<integer>"        -> ArrayType(ScalarType(:integer))
        #   "tuple<decimal, float>" -> TupleType([...])
        def parse(str)
          s = str.to_s.strip

          if (m = /\Aarray<(.+)>\z/.match(s))
            return ArrayType.new(parse(m[1]))
          end

          if (m = /\Atuple<(.+)>\z/.match(s))
            return TupleType.new(split_top_level(m[1]).map { |e| parse(e) })
          end

          kind = s.to_sym
          raise ArgumentError, "unknown type: #{str.inspect}" unless kind?(kind)

          ScalarType.new(kind)
        end

        # Split "decimal, array<integer>, float" on top-level commas only, so
        # nested tuples/arrays are not split inside their brackets.
        def split_top_level(str)
          parts = []
          depth = 0
          current = +""
          str.each_char do |ch|
            depth += 1 if ch == "<"
            depth -= 1 if ch == ">"
            if ch == "," && depth.zero?
              parts << current.strip
              current = +""
            else
              current << ch
            end
          end
          parts << current.strip unless current.strip.empty?
          parts
        end
      end
    end
  end
end
