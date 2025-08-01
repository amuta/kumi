# frozen_string_literal: true

module Kumi
  module Syntax
      CascadeExpression = Struct.new(:cases) do
        include Node

        def children = cases
      end
  end
end
