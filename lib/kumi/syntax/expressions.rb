module Kumi
  module Syntax
    module Expressions
      CallExpression = Struct.new(:fn_name, :args) do
        include Node
        def children = args
      end

      CascadeExpression = Struct.new(:cases) do
        include Node
        def children = cases
      end

      WhenCaseExpression = Struct.new(:condition, :result) do
        include Node
        def children = [condition, result]
      end

      ListExpression = Struct.new(:elements) do
        include Node
        def children = elements

        def size
          elements.size
        end
      end
    end
  end
end
