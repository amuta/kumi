# frozen_string_literal: true

module Kumi
  module Syntax
    HashExpression = Struct.new(:pairs) do
      include Node

      def children = pairs.flatten
    end
  end
end
