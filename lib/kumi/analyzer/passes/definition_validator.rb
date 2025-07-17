# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      # RESPONSIBILITY: Perform local structural validation on each declaration
      # DEPENDENCIES: None (can run independently)
      # PRODUCES: None (validation only)
      # INTERFACE: new(schema, state).run(errors)
      class DefinitionValidator < VisitorPass
        def run(errors)
          each_decl do |decl|
            visit(decl) { |node| validate_node(node, errors) }
          end
        end

        private

        def validate_node(node, errors)
          case node
          when Declarations::Attribute
            validate_attribute(node, errors)
          when Declarations::Trait
            validate_trait(node, errors)
          end
        end

        def validate_attribute(node, errors)
          return unless node.expression.nil?

          add_error(errors, node.loc, "attribute `#{node.name}` requires an expression")
        end

        def validate_trait(node, errors)
          return if node.expression.is_a?(Expressions::CallExpression)

          add_error(errors, node.loc, "trait `#{node.name}` must wrap a CallExpression")
        end
      end
    end
  end
end
