# frozen_string_literal: true

module Kumi
  module Syntax
    module Declarations
      Attribute = Struct.new(:name, :expression) do
        include Node
        def children = [expression]
      end

      Trait = Struct.new(:name, :expression) do
        include Node
        def children = [expression]
      end

      # For field metadata declarations inside input blocks
      FieldDecl = Struct.new(:name, :domain, :type) do
        include Node
        def children = []
      end
    end
  end
end
