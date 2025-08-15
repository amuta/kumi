# frozen_string_literal: true

require "bigdecimal"

module Kumi
  module Core
    module RubyParser
      module Sugar
        include Syntax

        ARITHMETIC_OPS = {
          :+ => :add, :- => :sub, :* => :mul,
          :/ => :div, :% => :mod, :** => :pow
        }.freeze

        COMPARISON_MAP = {
          :== => :eq, :!= => :ne, :< => :lt,
          :<= => :le, :> => :gt, :>= => :ge
        }.freeze

        LITERAL_TYPES = [
          Integer, String, Symbol, TrueClass, FalseClass, Float, Regexp, NilClass, BigDecimal
        ].freeze

        # Collection methods that can be applied to arrays/syntax nodes
        COLLECTION_METHODS = %i[
          sum size length first last sort reverse unique min max empty? flatten
          map_with_index indices
        ].freeze

        def self.ensure_literal(obj)
          return Kumi::Syntax::Literal.new(obj) if LITERAL_TYPES.any? { |type| obj.is_a?(type) }
          return obj if obj.is_a?(Syntax::Node)
          return obj.to_ast_node if obj.respond_to?(:to_ast_node)

          Kumi::Syntax::Literal.new(obj)
        end

        def self.syntax_expression?(obj)
          obj.is_a?(Syntax::Node) || obj.respond_to?(:to_ast_node)
        end

        # Create a call expression with consistent error handling
        def self.create_call_expression(fn_name, args)
          Kumi::Syntax::CallExpression.new(fn_name, args)
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
            COMPARISON_MAP.each do |op, op_name|
              define_method(op) do |other|
                other_node = Sugar.ensure_literal(other)
                Sugar.create_call_expression(op_name, [self, other_node])
              end
            end

            # Array access
            def [](index)
              Sugar.create_call_expression(:get, [self, Sugar.ensure_literal(index)])
            end

            # Unary minus
            def -@
              Sugar.create_call_expression(:sub, [Sugar.ensure_literal(0), self])
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
              Sugar.create_call_expression(:contains, [self, Sugar.ensure_literal(element)])
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
                    Sugar.create_call_expression(op_name, [Kumi::Syntax::Literal.new(self), other_node])
                  else
                    super(other)
                  end
                end
              end

              # Comparison operations with syntax expressions
              COMPARISON_MAP.each do |op, op_name|
                define_method(op) do |other|
                  if Sugar.syntax_expression?(other)
                    other_node = Sugar.ensure_literal(other)
                    Sugar.create_call_expression(op_name, [Kumi::Syntax::Literal.new(self), other_node])
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
                Sugar.create_call_expression(:concat, [Kumi::Syntax::Literal.new(self), other_node])
              else
                super
              end
            end

            [[:==, :eq], [:!=, :ne]].each do |op, op_name|
              define_method(op) do |other|
                if Sugar.syntax_expression?(other)
                  other_node = Sugar.ensure_literal(other)
                  Sugar.create_call_expression(op_name, [Kumi::Syntax::Literal.new(self), other_node])
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
              Kumi::Syntax::ArrayExpression.new(syntax_elements)
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

            # Define methods with arguments - use :contains internally
            define_method(:include?) do |*args|
              if any_syntax_expressions?
                array_literal = to_syntax_list
                call_args = [array_literal]
                call_args.concat(args.map { |arg| Sugar.ensure_literal(arg) })
                Sugar.create_call_expression(:contains, call_args)
              else
                super(*args)
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

        # Shared refinement for proxy objects that need to handle operators
        # Both DeclarationReferenceProxy and InputFieldProxy can use this
        module ProxyRefinement
          def self.extended(proxy_class)
            # Add operator methods directly to the proxy class
            proxy_class.class_eval do
              # Arithmetic operations
              ARITHMETIC_OPS.each do |op, op_name|
                define_method(op) do |other|
                  ast_node = to_ast_node
                  other_node = Sugar.ensure_literal(other)
                  Sugar.create_call_expression(op_name, [ast_node, other_node])
                end
              end

              # Comparison operations (including == and != that don't work with refinements)
              COMPARISON_MAP.each do |op, op_name|
                define_method(op) do |other|
                  ast_node = to_ast_node
                  other_node = Sugar.ensure_literal(other)
                  Sugar.create_call_expression(op_name, [ast_node, other_node])
                end
              end

              # Logical operations
              define_method(:&) do |other|
                ast_node = to_ast_node
                other_node = Sugar.ensure_literal(other)
                Sugar.create_call_expression(:and, [ast_node, other_node])
              end

              define_method(:|) do |other|
                ast_node = to_ast_node
                other_node = Sugar.ensure_literal(other)
                Sugar.create_call_expression(:or, [ast_node, other_node])
              end

              # Array access
              define_method(:[]) do |index|
                ast_node = to_ast_node
                Sugar.create_call_expression(:get, [ast_node, Sugar.ensure_literal(index)])
              end

              # Unary minus
              define_method(:-@) do
                ast_node = to_ast_node
                Sugar.create_call_expression(:sub, [Sugar.ensure_literal(0), ast_node])
              end

              # Override Ruby's built-in nil? method to transform into eq(nil)
              define_method(:nil?) do
                ast_node = to_ast_node
                nil_literal = Kumi::Syntax::Literal.new(nil)
                Sugar.create_call_expression(:eq, [ast_node, nil_literal])
              end
            end
          end
        end
      end
    end
  end
end
