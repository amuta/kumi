# frozen_string_literal: true

module Kumi
  module Analyzer
    class ConstantEvaluator
      include Syntax

      def initialize(definitions)
        @definitions = definitions
        @memo = {}
      end

      OPERATORS = {
        add: :+,
        subtract: :-,
        multiply: :*,
        divide: :/
      }.freeze

      def evaluate(node, visited = Set.new)
        return :unknown unless node
        return @memo[node] if @memo.key?(node)
        return node.value if node.is_a?(Literal)

        result = case node
                 when Binding then evaluate_binding(node, visited)
                 when CallExpression then evaluate_call_expression(node, visited)
                 else :unknown
                 end

        @memo[node] = result unless result == :unknown
        result
      end

      private

      def evaluate_binding(node, visited)
        return :unknown if visited.include?(node.name)

        visited << node.name
        definition = @definitions[node.name]
        return :unknown unless definition

        evaluate(definition.expression, visited)
      end

      def evaluate_call_expression(node, visited)
        return :unknown unless OPERATORS.key?(node.fn_name)

        args = node.args.map { |arg| evaluate(arg, visited) }
        return :unknown if args.any?(:unknown)

        args.reduce(OPERATORS[node.fn_name])
      end
    end
  end
end
