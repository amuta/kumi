# frozen_string_literal: true

module Kumi
  module Parser
    module Sugar
      include Syntax

      ARITHMETIC_OPS = {
        :+ => :add, :- => :subtract, :* => :multiply,
        :/ => :divide, :% => :modulo, :** => :power
      }.freeze

      COMPARISON_OPS = %i[< <= > >= == !=].freeze

      LITERAL_TYPES = [
        Integer, String, Symbol, TrueClass, FalseClass, Float, Regexp
      ].freeze

      # Collection methods that can be applied to arrays/syntax nodes
      COLLECTION_METHODS = %i[
        sum size length first last sort reverse unique min max empty? flatten
        map_with_index indices
      ].freeze

      def self.ensure_literal(obj)
        return Literal.new(obj) if LITERAL_TYPES.any? { |type| obj.is_a?(type) }
        return obj if obj.is_a?(Syntax::Node)
        return obj.to_ast_node if obj.respond_to?(:to_ast_node)

        Literal.new(obj)
      end

      def self.syntax_expression?(obj)
        obj.is_a?(Syntax::Node) || obj.respond_to?(:to_ast_node)
      end

      # Create a call expression with consistent error handling
      def self.create_call_expression(fn_name, args)
        Syntax::CallExpression.new(fn_name, args)
      end

      module ExpressionRefinement
        refine Syntax::Node do
          # Arithmetic operations
          ARITHMETIC_OPS.each do |op, op_name|
            define_method(op) do |other|
              other_node = Sugar.ensure_literal(other)
              Sugar.create_call_expression(op_name, [self, other_node])
            end
          end

          # Comparison operations
          COMPARISON_OPS.each do |op|
            define_method(op) do |other|
              other_node = Sugar.ensure_literal(other)
              Sugar.create_call_expression(op, [self, other_node])
            end
          end

          # Array access
          def [](index)
            Sugar.create_call_expression(:at, [self, Sugar.ensure_literal(index)])
          end

          # Unary minus
          def -@
            Sugar.create_call_expression(:subtract, [Sugar.ensure_literal(0), self])
          end

          # Logical operations
          def &(other)
            Sugar.create_call_expression(:and, [self, Sugar.ensure_literal(other)])
          end

          def |(other)
            Sugar.create_call_expression(:or, [self, Sugar.ensure_literal(other)])
          end

          # Collection methods - single argument (self)
          COLLECTION_METHODS.each do |method_name|
            next if method_name == :include? # Special case with element argument

            define_method(method_name) do
              Sugar.create_call_expression(method_name, [self])
            end
          end

          # Special case: include? takes an element argument
          def include?(element)
            Sugar.create_call_expression(:include?, [self, Sugar.ensure_literal(element)])
          end
        end
      end

      module NumericRefinement
        [Integer, Float].each do |klass|
          refine klass do
            # Arithmetic operations with syntax expressions
            ARITHMETIC_OPS.each do |op, op_name|
              define_method(op) do |other|
                if Sugar.syntax_expression?(other)
                  other_node = Sugar.ensure_literal(other)
                  Sugar.create_call_expression(op_name, [Syntax::Literal.new(self), other_node])
                else
                  super(other)
                end
              end
            end

            # Comparison operations with syntax expressions
            COMPARISON_OPS.each do |op|
              define_method(op) do |other|
                if Sugar.syntax_expression?(other)
                  other_node = Sugar.ensure_literal(other)
                  Sugar.create_call_expression(op, [Syntax::Literal.new(self), other_node])
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
              other_node = Sugar.ensure_literal(other)
              Sugar.create_call_expression(:concat, [Syntax::Literal.new(self), other_node])
            else
              super
            end
          end

          %i[== !=].each do |op|
            define_method(op) do |other|
              if Sugar.syntax_expression?(other)
                other_node = Sugar.ensure_literal(other)
                Sugar.create_call_expression(op, [Syntax::Literal.new(self), other_node])
              else
                super(other)
              end
            end
          end
        end
      end

      module ArrayRefinement
        refine Array do
          # Helper method to check if array contains any syntax expressions
          def any_syntax_expressions?
            any? { |item| Sugar.syntax_expression?(item) }
          end

          # Convert array to syntax list expression with all elements as syntax nodes
          def to_syntax_list
            syntax_elements = map { |item| Sugar.ensure_literal(item) }
            Syntax::ListExpression.new(syntax_elements)
          end

          # Create array method that works with syntax expressions
          def self.define_array_syntax_method(method_name, has_argument: false)
            define_method(method_name) do |*args|
              if any_syntax_expressions?
                array_literal = to_syntax_list
                call_args = [array_literal]
                call_args.concat(args.map { |arg| Sugar.ensure_literal(arg) }) if has_argument
                Sugar.create_call_expression(method_name, call_args)
              else
                super(*args)
              end
            end
          end

          # Define collection methods without arguments
          %i[sum size length first last sort reverse unique min max empty? flatten].each do |method_name|
            define_array_syntax_method(method_name)
          end

          # Define methods with arguments
          define_array_syntax_method(:include?, has_argument: true)
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
