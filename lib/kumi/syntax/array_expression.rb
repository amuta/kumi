# frozen_string_literal: true

module Kumi
  module Syntax
      ArrayExpression = Struct.new(:elements) do
        include Node

        def children = elements

        def size
          elements.size
        end
      end
  end
end
