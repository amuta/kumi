# frozen_string_literal: true

module Kumi
  module Core
    module Syntax
      ValueDeclaration = Struct.new(:name, :expression) do
        include Node

        def children = [expression]
      end
    end
  end
end
