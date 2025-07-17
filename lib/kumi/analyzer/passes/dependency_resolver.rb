# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      # RESPONSIBILITY: Build dependency graph and leaf map, validate references
      # DEPENDENCIES: :definitions from NameIndexer
      # PRODUCES: :dependency_graph - Hash of name → [DependencyEdge], :leaf_map - Hash of name → Set[nodes]
      # INTERFACE: new(schema, state).run(errors)
      class DependencyResolver < PassBase
        # A Struct to hold rich dependency information
        DependencyEdge = Struct.new(:to, :type, :via, keyword_init: true)
        include Syntax

        def run(errors)
          definitions = get_state(:definitions)
          input_meta = get_state(:input_meta)

          dependency_graph = Hash.new { |h, k| h[k] = [] }
          leaf_map = Hash.new { |h, k| h[k] = Set.new }

          each_decl do |decl|
            # Traverse the expression for each declaration, passing context down
            visit_with_context(decl.expression) do |node, context|
              process_node(node, decl, dependency_graph, leaf_map, definitions, input_meta, errors, context)
            end
          end

          set_state(:dependency_graph, dependency_graph.transform_values(&:freeze).freeze)
          set_state(:leaf_map, leaf_map.transform_values(&:freeze).freeze)
        end

        private

        def process_node(node, decl, graph, leaves, definitions, input_meta, errors, context)
          case node
          when Binding
            add_error(errors, node.loc, "undefined reference to `#{node.name}`") unless definitions.key?(node.name)
            add_dependency_edge(graph, decl.name, node.name, :ref, context[:via])
          when FieldRef
            add_error(errors, node.loc, "undeclared input `#{node.name}`") unless input_meta.key?(node.name)
            add_dependency_edge(graph, decl.name, node.name, :key, context[:via])
            leaves[decl.name] << node # put it back
          when Literal
            leaves[decl.name] << node
          end
        end

        def add_dependency_edge(graph, from, to, type, via)
          edge = DependencyEdge.new(to: to, type: type, via: via)
          graph[from] << edge
        end

        # Custom visitor that passes context (like function name) down the tree
        def visit_with_context(node, context = {}, &block)
          return unless node

          yield(node, context)

          new_context = if node.is_a?(Expressions::CallExpression)
                          { via: node.fn_name }
                        else
                          context
                        end

          node.children.each { |child| visit_with_context(child, new_context, &block) }
        end
      end
    end
  end
end
