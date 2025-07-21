# frozen_string_literal: true

module Kumi
  module Syntax
    module Expressions
      CallExpression = Struct.new(:fn_name, :args) do
        include Node
        def children = args

        # Logical AND operator for chaining expressions
        def &(other)
          CallExpression.new(:and, [self, ensure_node(other)])
        end

        private

        def ensure_node(obj)
          case obj
          when Integer, String, Symbol, TrueClass, FalseClass, Float, Regexp
            TerminalExpressions::Literal.new(obj)
          when Syntax::Node
            obj
          when Kumi::Parser::DslBuilderContext::ComposableTraitRef
            obj.to_ast_node
          else
            TerminalExpressions::Literal.new(obj)
          end
        end
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
