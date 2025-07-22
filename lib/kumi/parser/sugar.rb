# frozen_string_literal: true

module Kumi
  module Parser
    module Sugar
      # Module that can be directly included to add operator overloads
      module ExpressionOperators
        include Syntax

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
            CallExpression.new(op_name, [self_node, other_node])
          end
        end

        COMPARISON_OPS.each do |op|
          define_method(op) do |other|
            # Ensure both self and other are unwrapped to pure AST nodes
            self_node = respond_to?(:to_ast_node) ? to_ast_node : self
            other_node = ensure_literal(other)
            CallExpression.new(op, [self_node, other_node])
          end
        end

        def [](index)
          CallExpression.new(:at, [self, ensure_literal(index)])
        end

        def -@
          CallExpression.new(:subtract, [ensure_literal(0), self])
        end

        def &(other)
          CallExpression.new(:and, [self, ensure_literal(other)])
        end
      end

      # Refinement for Expression objects to add operator overloads
      module ExpressionRefinement
        include Syntax

        refine Syntax::Node do
          # Include the same operator methods from ExpressionOperators
          ExpressionOperators::ARITHMETIC_OPS.each do |op, op_name|
            define_method(op) do |other|
              CallExpression.new(op_name, [self, ensure_literal(other)])
            end
          end

          ExpressionOperators::COMPARISON_OPS.each do |op|
            define_method(op) do |other|
              CallExpression.new(op, [self, ensure_literal(other)])
            end
          end

          def [](index)
            CallExpression.new(:at, [self, ensure_literal(index)])
          end

          def -@
            CallExpression.new(:subtract, [ensure_literal(0), self])
          end

          def &(other)
            CallExpression.new(:and, [self, ensure_literal(other)])
          end

          private

          def ensure_literal(obj)
            return Literal.new(obj) if [Integer, String, Symbol, TrueClass, FalseClass, Float, Regexp].any? { |type| obj.is_a?(type) }
            return obj if obj.is_a?(Syntax::Node)

            Literal.new(obj)
          end
        end
      end

      # Refinement for Numeric types to lift literals when operating with Expressions
      module NumericRefinement
        include Syntax
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
                  CallExpression.new(op_name, [Literal.new(self), other_node])
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
                  CallExpression.new(op, [Literal.new(self), other_node])
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
        include Syntax

        refine String do
          def +(other)
            if other.is_a?(Syntax::Node) || other.respond_to?(:to_ast_node)
              # Unwrap Sugar wrappers to pure AST nodes
              other_node = other.respond_to?(:to_ast_node) ? other.to_ast_node : other
              CallExpression.new(:concat, [Literal.new(self), other_node])
            else
              super
            end
          end

          %i[== !=].each do |op|
            define_method(op) do |other|
              if other.is_a?(Syntax::Node) || other.respond_to?(:to_ast_node)
                # Unwrap Sugar wrappers to pure AST nodes
                other_node = other.respond_to?(:to_ast_node) ? other.to_ast_node : other
                CallExpression.new(op, [Literal.new(self), other_node])
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
