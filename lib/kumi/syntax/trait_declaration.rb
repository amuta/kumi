# frozen_string_literal: true

module Kumi
  module Syntax
    TraitDeclaration = Struct.new(:name, :expression) do
      include Node

      def children = [expression]
      def kind = :trait
    end
  end
end
