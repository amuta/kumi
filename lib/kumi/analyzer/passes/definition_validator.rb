# frozen_string_literal: true

# RESPONSIBILITY:
#   - Perform local, structural checks on each declaration.
module Kumi
  module Analyzer
    module Passes
      class DefinitionValidator < Visitor
        def initialize(schema, state)
          super()
          @schema = schema
          @state = state
        end

        def run(errors)
          each_decl do |decl|
            visit(decl) { |node| handle(node, errors) }
          end
        end

        private

        def handle(node, errors)
          case node
          when Syntax::Attribute
            errors << [node.loc, "attribute `#{node.name}` requires an expression"] if node.expression.nil?
          when Syntax::Trait
            unless node.expression.is_a?(Syntax::Expressions::CallExpression)
              errors << [node.loc, "trait `#{node.name}` must wrap a CallExpression"]
            end
          end
        end

        def each_decl(&block)
          @schema.attributes.each(&block)
          @schema.traits.each(&block)
        end
      end
    end
  end
end
