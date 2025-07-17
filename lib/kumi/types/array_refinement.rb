# frozen_string_literal: true

module Kumi
  module Types
    module ArrayRefinement
      refine ::Array.singleton_class do
        def [](arg = nil, *rest)
          # If called with >1 arg (Array[1,2]) or non‑type, fall back
          return super unless rest.empty? && Types.resolvable?(arg)

          Types.array(Types.coerce(arg))
        end
      end
    end
  end
end
