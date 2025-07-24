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

          def |(other)
            Syntax::CallExpression.new(:or, [self, Sugar.ensure_literal(other)])
          end

          # Collection methods  
          def map_with_index
            Syntax::CallExpression.new(:map_with_index, [self])
          end

          def indices
            Syntax::CallExpression.new(:indices, [self])
          end

          def flatten
            Syntax::CallExpression.new(:flatten, [self])
          end

          def sum
            Syntax::CallExpression.new(:sum, [self])
          end

          def size
            Syntax::CallExpression.new(:size, [self])
          end

          def length
            Syntax::CallExpression.new(:length, [self])
          end

          def reverse
            Syntax::CallExpression.new(:reverse, [self])
          end

          def sort
            Syntax::CallExpression.new(:sort, [self])
          end

          def unique
            Syntax::CallExpression.new(:unique, [self])
          end

          def first
            Syntax::CallExpression.new(:first, [self])
          end

          def last
            Syntax::CallExpression.new(:last, [self])
          end

          def empty?
            Syntax::CallExpression.new(:empty?, [self])
          end

          def include?(element)
            Syntax::CallExpression.new(:include?, [self, Sugar.ensure_literal(element)])
          end

          def min
            Syntax::CallExpression.new(:min, [self])
          end

          def max
            Syntax::CallExpression.new(:max, [self])
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

      module ArrayRefinement
        refine Array do
          def sum
            # Convert array of Kumi syntax nodes to a Kumi array literal, then sum
            if all? { |item| Sugar.syntax_expression?(item) }
              array_literal = Syntax::ListExpression.new(self)
              Syntax::CallExpression.new(:sum, [array_literal])
            else
              super
            end
          end

          def size
            if all? { |item| Sugar.syntax_expression?(item) }
              array_literal = Syntax::ListExpression.new(self)
              Syntax::CallExpression.new(:size, [array_literal])
            else
              super
            end
          end

          def length
            if all? { |item| Sugar.syntax_expression?(item) }
              array_literal = Syntax::ListExpression.new(self)
              Syntax::CallExpression.new(:length, [array_literal])
            else
              super
            end
          end

          def first
            if all? { |item| Sugar.syntax_expression?(item) }
              array_literal = Syntax::ListExpression.new(self)
              Syntax::CallExpression.new(:first, [array_literal])
            else
              super
            end
          end

          def last
            if all? { |item| Sugar.syntax_expression?(item) }
              array_literal = Syntax::ListExpression.new(self)
              Syntax::CallExpression.new(:last, [array_literal])
            else
              super
            end
          end

          def sort
            if all? { |item| Sugar.syntax_expression?(item) }
              array_literal = Syntax::ListExpression.new(self)
              Syntax::CallExpression.new(:sort, [array_literal])
            else
              super
            end
          end

          def reverse
            if all? { |item| Sugar.syntax_expression?(item) }
              array_literal = Syntax::ListExpression.new(self)
              Syntax::CallExpression.new(:reverse, [array_literal])
            else
              super
            end
          end

          def unique
            if all? { |item| Sugar.syntax_expression?(item) }
              array_literal = Syntax::ListExpression.new(self)
              Syntax::CallExpression.new(:unique, [array_literal])
            else
              super
            end
          end

          def min
            if all? { |item| Sugar.syntax_expression?(item) }
              array_literal = Syntax::ListExpression.new(self)
              Syntax::CallExpression.new(:min, [array_literal])
            else
              super
            end
          end

          def max
            if all? { |item| Sugar.syntax_expression?(item) }
              array_literal = Syntax::ListExpression.new(self)
              Syntax::CallExpression.new(:max, [array_literal])
            else
              super
            end
          end

          def empty?
            if all? { |item| Sugar.syntax_expression?(item) }
              array_literal = Syntax::ListExpression.new(self)
              Syntax::CallExpression.new(:empty?, [array_literal])
            else
              super
            end
          end

          def include?(element)
            if all? { |item| Sugar.syntax_expression?(item) }
              array_literal = Syntax::ListExpression.new(self)
              Syntax::CallExpression.new(:include?, [array_literal, Sugar.ensure_literal(element)])
            else
              super
            end
          end
        end
      end

      module ModuleRefinement
        refine Module do
          # Allow modules to provide schema utilities and helpers
          def with_schema_utilities
            include Kumi::Schema if respond_to?(:include)
            extend Kumi::Schema if respond_to?(:extend)
          end

          # Helper for defining schema constants that can be used in multiple schemas
          def schema_const(name, value)
            const_set(name, value.freeze)
          end

          # Enable easy schema composition
          def compose_schema(*modules)
            modules.each do |mod|
              include mod if mod.is_a?(Module)
            end
          end
        end
      end
    end
  end
end
