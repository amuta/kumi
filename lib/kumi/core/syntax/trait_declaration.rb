# frozen_string_literal: true

module Kumi::Core
  module Syntax
    TraitDeclaration = Struct.new(:name, :expression) do
      include Node

      def children = [expression]
    end
  end
end
