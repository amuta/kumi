# frozen_string_literal: true

module Kumi
  module Syntax
    ValueDeclaration = Struct.new(:name, :expression) do
      include Node

      def children = [expression]
      def kind = :value
    end
  end
end
