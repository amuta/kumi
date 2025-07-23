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

        if node.is_a?(Binding)
          return :unknown if visited.include?(node.name)

          visited << node.name

          definition = @definitions[node.name]
          return :unknown unless definition

          @memo[node] = evaluate(definition.expression, visited)
          return @memo[node]
        end

        if node.is_a?(CallExpression)
          return :unknown unless OPERATORS.key?(node.fn_name)

          args = node.args.map { |arg| evaluate(arg, visited) }
          return :unknown if args.any?(:unknown)

          @memo[node] = args.reduce(OPERATORS[node.fn_name])
          return @memo[node]
        end

        :unknown
      end
    end
  end
end
