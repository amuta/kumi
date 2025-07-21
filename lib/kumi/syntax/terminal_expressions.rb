# frozen_string_literal: true

require_relative "node"

module Kumi
  module Syntax
    module TerminalExpressions
      # Leaf expressions that represent a value or reference and terminate a branch.

      Literal = Struct.new(:value) do
        include Node
        def children = []
      end

      # For field usage/reference in expressions (input.field_name)
      FieldRef = Struct.new(:name) do
        include Node
        include Syntax::Expressions
        def children = []

        # Comparison operators - create CallExpression nodes directly
        def >=(other)
          Expressions::CallExpression.new(:>=, [self, ensure_literal(other)])
        end

        def <=(other)
          Expressions::CallExpression.new(:<=, [self, ensure_literal(other)])
        end

        def >(other)
          Expressions::CallExpression.new(:>, [self, ensure_literal(other)])
        end

        def <(other)
          Expressions::CallExpression.new(:<, [self, ensure_literal(other)])
        end

        def ==(other)
          Expressions::CallExpression.new(:==, [self, ensure_literal(other)])
        end

        def !=(other)
          Expressions::CallExpression.new(:!=, [self, ensure_literal(other)])
        end

        private

        def ensure_literal(obj)
          case obj
          when Integer, String, Symbol, TrueClass, FalseClass, Float, Regexp
            Literal.new(obj)
          when Syntax::Node
            obj
          else
            Literal.new(obj)
          end
        end
      end

      Binding = Struct.new(:name) do
        include Node
        def children = []
      end
    end
  end
end
