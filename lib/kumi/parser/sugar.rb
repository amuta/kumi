# frozen_string_literal: true

module Kumi
  module Parser
    module Sugar
      include Syntax

      ARITHMETIC_OPS = { :+ => :add, :- => :subtract, :* => :multiply,
                         :/ => :divide, :% => :modulo, :** => :power }.freeze
      COMPARISON_OPS = %i[< <= > >= == !=].freeze
      LITERAL_TYPES = [Integer, String, Symbol, TrueClass, FalseClass, Float, Regexp].freeze

      def self.ensure_literal(obj)
        return Literal.new(obj) if LITERAL_TYPES.any? { |type| obj.is_a?(type) }
        return obj if obj.is_a?(Syntax::Node)
        return obj.to_ast_node if obj.respond_to?(:to_ast_node)

        Literal.new(obj)
      end

      def self.syntax_expression?(obj)
        obj.is_a?(Syntax::Node) || obj.respond_to?(:to_ast_node)
      end

      module ExpressionRefinement
        refine Syntax::Node do
          ARITHMETIC_OPS.each do |op, op_name|
            define_method(op) do |other|
              other_node = Sugar.ensure_literal(other)
              Syntax::CallExpression.new(op_name, [self, other_node])
            end
          end

          COMPARISON_OPS.each do |op|
            define_method(op) do |other|
              other_node = Sugar.ensure_literal(other)
              Syntax::CallExpression.new(op, [self, other_node])
            end
          end

          def [](index)
            Syntax::CallExpression.new(:at, [self, Sugar.ensure_literal(index)])
          end

          def -@
            Syntax::CallExpression.new(:subtract, [Sugar.ensure_literal(0), self])
          end

          def &(other)
            Syntax::CallExpression.new(:and, [self, Sugar.ensure_literal(other)])
          end
        end
      end

      module NumericRefinement
        [Integer, Float].each do |klass|
          refine klass do
            ARITHMETIC_OPS.each do |op, op_name|
              define_method(op) do |other|
                if Sugar.syntax_expression?(other)
                  other_node = other.respond_to?(:to_ast_node) ? other.to_ast_node : other
                  Syntax::CallExpression.new(op_name, [Syntax::Literal.new(self), other_node])
                else
                  super(other)
                end
              end
            end

            COMPARISON_OPS.each do |op|
              define_method(op) do |other|
                if Sugar.syntax_expression?(other)
                  other_node = other.respond_to?(:to_ast_node) ? other.to_ast_node : other
                  Syntax::CallExpression.new(op, [Syntax::Literal.new(self), other_node])
                else
                  super(other)
                end
              end
            end
          end
        end
      end

      module StringRefinement
        refine String do
          def +(other)
            if Sugar.syntax_expression?(other)
              other_node = other.respond_to?(:to_ast_node) ? other.to_ast_node : other
              Syntax::CallExpression.new(:concat, [Syntax::Literal.new(self), other_node])
            else
              super
            end
          end

          %i[== !=].each do |op|
            define_method(op) do |other|
              if Sugar.syntax_expression?(other)
                other_node = other.respond_to?(:to_ast_node) ? other.to_ast_node : other
                Syntax::CallExpression.new(op, [Syntax::Literal.new(self), other_node])
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
