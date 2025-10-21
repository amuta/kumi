# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      class ConstantEvaluator
        NAST = Kumi::Core::NAST

        def self.evaluate(call_node, registry, known_constants = {})
          new(call_node, registry, known_constants).evaluate
        end

        def initialize(call_node, registry, known_constants)
          @node = call_node
          @registry = registry
          @known_constants = known_constants
        end

        def evaluate
          arg_values = @node.args.map { |arg| resolve_constant_value(arg) }

          return nil if arg_values.any?(&:nil?)

          func = @registry.function(@node.fn)

          return nil unless func.respond_to?(:folding_class_method) && func.folding_class_method

          method_name = func.folding_class_method.to_sym

          ConstantFoldingHelpers.send(method_name, *arg_values)
        rescue StandardError
          nil
        end

        private

        def resolve_constant_value(node)
          case node
          when NAST::Const
            node.value
          when NAST::Ref
            const_node = @known_constants[node.name]
            resolve_constant_value(const_node) if const_node
          when NAST::Tuple
            values = node.args.map { |arg| resolve_constant_value(arg) }
            values.all? ? values : nil
          end
        end
      end
    end
  end
end
