# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      # RESPONSIBILITY: Build dependency graph and leaf map, validate references
      # DEPENDENCIES: :definitions, :input_meta
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
          reverse_dependencies = Hash.new { |h, k| h[k] = [] }
          leaf_map = Hash.new { |h, k| h[k] = Set.new }

          each_decl do |decl|
            # Traverse the expression for each declaration, passing context down
            visit_with_context(decl.expression) do |node, context|
              process_node(node, decl, dependency_graph, reverse_dependencies, leaf_map, definitions, input_meta, errors, context)
            end
          end

          # Compute transitive closure of reverse dependencies
          transitive_dependents = compute_transitive_closure(reverse_dependencies)

          state.with(:dependency_graph, dependency_graph.transform_values(&:freeze).freeze)
               .with(:transitive_dependents, transitive_dependents.freeze)
               .with(:leaf_map, leaf_map.transform_values(&:freeze).freeze)
        end

        private

        def process_node(node, decl, graph, reverse_deps, leaves, definitions, input_meta, errors, context)
          case node
          when Binding
            report_error(errors, "undefined reference to `#{node.name}`", location: node.loc) unless definitions.key?(node.name)
            add_dependency_edge(graph, reverse_deps, decl.name, node.name, :ref, context[:via])
          when FieldRef
            report_error(errors, "undeclared input `#{node.name}`", location: node.loc) unless input_meta.key?(node.name)
            add_dependency_edge(graph, reverse_deps, decl.name, node.name, :key, context[:via])
            leaves[decl.name] << node # put it back
          when Literal
            leaves[decl.name] << node
          end
        end

        def add_dependency_edge(graph, reverse_deps, from, to, type, via)
          edge = DependencyEdge.new(to: to, type: type, via: via)
          graph[from] << edge
          reverse_deps[to] << from
        end

        # Compute transitive closure: for each key, find ALL declarations that depend on it
        def compute_transitive_closure(reverse_dependencies)
          transitive = {}

          # Collect all keys first to avoid iteration issues
          all_keys = reverse_dependencies.keys

          all_keys.each do |key|
            visited = Set.new
            to_visit = [key]
            dependents = Set.new

            while to_visit.any?
              current = to_visit.shift
              next if visited.include?(current)

              visited.add(current)

              # Get direct dependents
              direct_dependents = reverse_dependencies[current] || []
              direct_dependents.each do |dependent|
                next if visited.include?(dependent)

                dependents << dependent
                to_visit << dependent
              end
            end

            transitive[key] = dependents.to_a
          end

          transitive
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
