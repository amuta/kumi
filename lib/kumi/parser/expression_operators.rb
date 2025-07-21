# frozen_string_literal: true

module Kumi
  module Parser
    module ExpressionOperators
      include Syntax::Expressions

      # Comparison operators
      def ==(other)
        create_call_expression(:==, other)
      end

      def >(other)
        create_call_expression(:>, other)
      end

      def <(other)
        create_call_expression(:<, other)
      end

      def >=(other)
        create_call_expression(:>=, other)
      end

      def <=(other)
        create_call_expression(:<=, other)
      end

      def !=(other)
        create_call_expression(:!=, other)
      end

      # Logical AND operator (maintaining constraint satisfaction)
      def &(other)
        create_call_expression(:and, other)
      end

      # Fluent API for AND operations - maintains conjunctive constraints
      # Usage: (input.age >= 18).and(input.age < 65)
      def and(other)
        create_call_expression(:and, other)
      end

      # NOTE: OR operations intentionally excluded to maintain constraint satisfaction
      # Kumi's constraint system relies on conjunctive (AND-only) logic for solvability

      # Math operators
      def +(other)
        create_call_expression(:add, other)
      end

      def -(other)
        create_call_expression(:subtract, other)
      end

      def *(other)
        create_call_expression(:multiply, other)
      end

      def /(other)
        create_call_expression(:divide, other)
      end

      def %(other)
        create_call_expression(:modulo, other)
      end

      def **(other)
        create_call_expression(:power, other)
      end

      private

      def create_call_expression(operator, other)
        # Get context from the current node
        context = if respond_to?(:context)
                    self.context
                  elsif defined?(@context)
                    @context
                  else
                    # Fallback: try to get context from call stack
                    # This is a bit hacky but should work for most cases
                    caller_locations.each do |location|
                      if location.label.include?("DslBuilderContext")
                        left_operand = respond_to?(:to_ast_node) ? to_ast_node : self
                        return CallExpression.new(operator, [left_operand, ensure_syntax_with_fallback(other)])
                      end
                    end
                    raise "Cannot determine context for operator #{operator}"
                  end

        loc = context.current_location
        other_expr = context.send(:ensure_syntax, other, loc)
        left_operand = respond_to?(:to_ast_node) ? to_ast_node : self
        CallExpression.new(operator, [left_operand, other_expr], loc: loc)
      end

      def ensure_syntax_with_fallback(obj)
        # Fallback ensure_syntax when we can't access context
        case obj
        when Integer, String, Symbol, TrueClass, FalseClass, Float, Regexp
          Syntax::TerminalExpressions::Literal.new(obj)
        when Array
          Syntax::Expressions::ListExpression.new(obj.map { |e| ensure_syntax_with_fallback(e) })
        when Syntax::Node
          obj
        else
          raise "Invalid expression: #{obj.inspect}"
        end
      end
    end
  end
end
