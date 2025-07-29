# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      # RESPONSIBILITY: Perform local structural validation on each declaration
      # DEPENDENCIES: :definitions
      # PRODUCES: None (validation only)
      # INTERFACE: new(schema, state).run(errors)
      class DefinitionValidator < VisitorPass
        def run(errors)
          each_decl do |decl|
            visit(decl) { |node| validate_node(node, errors) }
          end
          state
        end

        private

        def validate_node(node, errors)
          case node
          when Kumi::Syntax::ValueDeclaration
            validate_attribute(node, errors)
          when Kumi::Syntax::TraitDeclaration
            validate_trait(node, errors)
          end
        end

        def validate_attribute(node, errors)
          return unless node.expression.nil?

          report_error(errors, "attribute `#{node.name}` requires an expression", location: node.loc)
        end

        def validate_trait(node, errors)
          return if node.expression.is_a?(Kumi::Syntax::CallExpression)

          report_error(errors, "trait `#{node.name}` must wrap a CallExpression", location: node.loc)
        end
      end
    end
  end
end
