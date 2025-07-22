# frozen_string_literal: true

module Kumi
  module Parser
    module Sugar
      include Syntax

      # Module that can be directly included to add operator overloads
      module ExpressionOperators
        ARITHMETIC_OPS = { :+ => :add, :- => :subtract, :* => :multiply,
                           :/ => :divide, :% => :modulo, :** => :power }.freeze
        COMPARISON_OPS = %i[< <= > >= == !=].freeze

        # Special handling for + operator to choose between add and concat for obvious string cases
        # Handle other arithmetic operators normally
        ARITHMETIC_OPS.each do |op, op_name|
          define_method(op) do |other|
            # Ensure both self and other are unwrapped to pure AST nodes
            self_node = respond_to?(:to_ast_node) ? to_ast_node : self
            other_node = ensure_literal(other)
            Syntax::Expressions::CallExpression.new(op_name, [self_node, other_node])
          end
        end

        COMPARISON_OPS.each do |op|
          define_method(op) do |other|
            # Ensure both self and other are unwrapped to pure AST nodes
            self_node = respond_to?(:to_ast_node) ? to_ast_node : self
            other_node = ensure_literal(other)
            Syntax::Expressions::CallExpression.new(op, [self_node, other_node])
          end
        end

        def [](index)
          self_node = respond_to?(:to_ast_node) ? to_ast_node : self
          index_node = ensure_literal(index)
          Syntax::Expressions::CallExpression.new(:at, [self_node, index_node])
        end

        def -@
          self_node = respond_to?(:to_ast_node) ? to_ast_node : self
          Syntax::Expressions::CallExpression.new(:subtract, [ensure_literal(0), self_node])
        end

        private

        def ensure_literal(value)
          # Check if it's a Sugar wrapper first and unwrap it
          if value.respond_to?(:to_ast_node)
            value.to_ast_node
          elsif value.is_a?(Syntax::Node)
            value
          else
            Syntax::TerminalExpressions::Literal.new(value)
          end
        end
      end

      # Refinement for Expression objects to add operator overloads
      module ExpressionRefinement
        refine Syntax::Node do
          # Include the same operator methods from ExpressionOperators
          ExpressionOperators::ARITHMETIC_OPS.each do |op, op_name|
            define_method(op) do |other|
              Syntax::Expressions::CallExpression.new(op_name, [self, ensure_literal(other)])
            end
          end

          ExpressionOperators::COMPARISON_OPS.each do |op|
            # Skip == since it's already defined for comparison
            next if op == :==

            define_method(op) do |other|
              Syntax::Expressions::CallExpression.new(op, [self, ensure_literal(other)])
            end
          end

          def [](index)
            Syntax::Expressions::CallExpression.new(:at, [self, ensure_literal(index)])
          end

          def -@
            Syntax::Expressions::CallExpression.new(:subtract, [ensure_literal(0), self])
          end

          private

          def ensure_literal(value)
            case value
            when Syntax::Node
              value
            else
              Syntax::TerminalExpressions::Literal.new(value)
            end
          end

          def -@
            Syntax::Expressions::CallExpression.new(:subtract, [Syntax::TerminalExpressions::Literal.new(0), self])
          end

          private

          def ensure_literal(obj)
            if [Integer, String, Symbol, TrueClass, FalseClass, Float, Regexp].any? { |type| obj.is_a?(type) }
              return Syntax::TerminalExpressions::Literal.new(obj)
            end
            return obj if obj.is_a?(Syntax::Node)

            Syntax::TerminalExpressions::Literal.new(obj)
          end
        end
      end

      # Refinement for Numeric types to lift literals when operating with Expressions
      module NumericRefinement
        ARITHMETIC_OPS = ExpressionOperators::ARITHMETIC_OPS
        COMPARISON_OPS = ExpressionOperators::COMPARISON_OPS
        NUMERIC_TYPES = [Integer, Float].freeze

        NUMERIC_TYPES.each do |klass|
          refine klass do
            ARITHMETIC_OPS.each do |op, op_name|
              define_method(op) do |other|
                if other.is_a?(Syntax::Node) || other.respond_to?(:to_ast_node)
                  # Unwrap Sugar wrappers to pure AST nodes
                  other_node = other.respond_to?(:to_ast_node) ? other.to_ast_node : other
                  Syntax::Expressions::CallExpression.new(op_name, [Syntax::TerminalExpressions::Literal.new(self), other_node])
                else
                  super(other)
                end
              end
            end

            COMPARISON_OPS.each do |op|
              define_method(op) do |other|
                if other.is_a?(Syntax::Node) || other.respond_to?(:to_ast_node)
                  # Unwrap Sugar wrappers to pure AST nodes
                  other_node = other.respond_to?(:to_ast_node) ? other.to_ast_node : other
                  Syntax::Expressions::CallExpression.new(op, [Syntax::TerminalExpressions::Literal.new(self), other_node])
                else
                  super(other)
                end
              end
            end
          end
        end
      end

      # Refinement for String type to lift literals when operating with Expressions
      module StringRefinement
        refine String do
          def +(other)
            if other.is_a?(Syntax::Node) || other.respond_to?(:to_ast_node)
              # Unwrap Sugar wrappers to pure AST nodes
              other_node = other.respond_to?(:to_ast_node) ? other.to_ast_node : other
              Syntax::Expressions::CallExpression.new(:concat, [Syntax::TerminalExpressions::Literal.new(self), other_node])
            else
              super
            end
          end

          %i[== !=].each do |op|
            define_method(op) do |other|
              if other.is_a?(Syntax::Node) || other.respond_to?(:to_ast_node)
                # Unwrap Sugar wrappers to pure AST nodes
                other_node = other.respond_to?(:to_ast_node) ? other.to_ast_node : other
                Syntax::Expressions::CallExpression.new(op, [Syntax::TerminalExpressions::Literal.new(self), other_node])
              else
                super(other)
              end
            end
          end
        end
      end
    end
  end
end
