# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      # Base class for analyzer passes that need to traverse the AST using the visitor pattern
      class VisitorPass < PassBase
        # Visit a node and all its children using depth-first traversal
        # @param node [Syntax::Node] The node to visit
        # @yield [Syntax::Node] Each node in the traversal
        def visit(node, &block)
          return unless node

          yield(node)
          node.children.each { |child| visit(child, &block) }
        end

        protected

        # Helper to visit each declaration's expression tree
        # @param errors [Array] Error accumulator
        # @yield [Syntax::Node, Syntax::Declarations::Base] Each node and its containing declaration
        def visit_all_expressions(errors, &block)
          each_decl do |decl|
            visit(decl.expression) { |node| block.call(node, decl, errors) }
          end
        end

        # Helper to visit only specific node types
        # @param node_types [Array<Class>] Node types to match
        # @param errors [Array] Error accumulator  
        # @yield [Syntax::Node, Syntax::Declarations::Base] Matching nodes and their declarations
        def visit_nodes_of_type(*node_types, errors:, &block)
          visit_all_expressions(errors) do |node, decl, errs|
            if node_types.any? { |type| node.is_a?(type) }
              block.call(node, decl, errs)
            end
          end
        end
      end
    end
  end
end