# frozen_string_literal: true

# RESPONSIBILITY:
#   - Build the :dependency_graph and :leaf_map.
#   - Check for undefined references.
module Kumi
  module Analyzer
    module Passes
      class DependencyResolver < Visitor
        # A Struct to hold rich dependency information
        DependencyEdge = Struct.new(:to, :type, :via, keyword_init: true)

        def initialize(schema, state)
          @schema = schema
          @state  = state
        end

        def run(errors)
          rich_graph = Hash.new { |h, k| h[k] = [] }
          raw_leaves = Hash.new { |h, k| h[k] = Set.new }
          defs = @state[:definitions] || {}

          each_decl do |decl|
            # Traverse the expression for each declaration, passing context down.
            visit(decl.expression) do |node, context|
              handle(node, decl, rich_graph, raw_leaves, defs, errors, context)
            end
          end

          @state[:dependency_graph] = rich_graph.transform_values(&:freeze).freeze
          @state[:leaf_map] = raw_leaves.transform_values(&:freeze).freeze
        end

        private

        def handle(node, decl, graph, leaves, defs, errors, context)
          case node
          when Syntax::TerminalExpressions::Binding
            errors << [node.loc, "undefined reference to `#{node.name}`"] unless defs.key?(node.name)
            # Create a rich edge describing the dependency
            edge = DependencyEdge.new(to: node.name, type: :ref, via: context[:via])
            graph[decl.name] << edge
          when Syntax::TerminalExpressions::Field
            edge = DependencyEdge.new(to: node.name, type: :key, via: context[:via])
            graph[decl.name] << edge
            leaves[decl.name] << node
          when Syntax::TerminalExpressions::Literal
            leaves[decl.name] << node
          end
        end

        # This custom visitor passes context (like the function name) down the tree.
        def visit(node, context = {}, &block)
          return unless node

          yield(node, context)

          new_context = if node.is_a?(Syntax::Expressions::CallExpression)
                          { via: node.fn_name }
                        else
                          context
                        end

          node.children.each { |c| visit(c, new_context, &block) }
        end

        def each_decl(&b)
          @schema.attributes.each(&b)
          @schema.traits.each(&b)
        end
      end
    end
  end
end
