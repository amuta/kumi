# frozen_string_literal: true

module Kumi::Core
  module Syntax
    Literal = Struct.new(:value) do
      include Node

      def children = []
    end
  end
end
