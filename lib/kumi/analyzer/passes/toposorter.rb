# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      # RESPONSIBILITY: Compute topological ordering of declarations from dependency graph
      # DEPENDENCIES: :dependency_graph from DependencyResolver, :definitions from NameIndexer
      # PRODUCES: :topo_order - Array of declaration names in evaluation order
      # INTERFACE: new(schema, state).run(errors)
      class Toposorter < PassBase
        def run(errors)
          dependency_graph = get_state(:dependency_graph, required: false) || {}
          definitions = get_state(:definitions, required: false) || {}

          order = compute_topological_order(dependency_graph, definitions, errors)
          state.with(:topo_order, order)
        end

        private

        def compute_topological_order(graph, definitions, errors)
          temp_marks = Set.new
          perm_marks = Set.new
          order = []

          visit_node = lambda do |node|
            return if perm_marks.include?(node)

            if temp_marks.include?(node)
              report_unexpected_cycle(temp_marks, node, errors)
              return
            end

            temp_marks << node
            Array(graph[node]).each { |edge| visit_node.call(edge.to) }
            temp_marks.delete(node)
            perm_marks << node

            # Only include declaration nodes in the final order
            order << node if definitions.key?(node)
          end

          # Visit all nodes in the graph
          graph.each_key { |node| visit_node.call(node) }

          # Also visit any definitions that aren't in the dependency graph
          # (i.e., declarations with no dependencies)
          definitions.each_key { |node| visit_node.call(node) }

          order.freeze
        end

        def report_unexpected_cycle(temp_marks, current_node, errors)
          cycle_path = temp_marks.to_a.join(" → ") + " → #{current_node}"

          # Try to find the first declaration in the cycle for location info
          first_decl = find_declaration_by_name(temp_marks.first || current_node)
          location = first_decl&.loc

          add_error(errors, location, "cycle detected: #{cycle_path}")
        end

        def find_declaration_by_name(name)
          return nil unless schema

          schema.attributes.find { |attr| attr.name == name } ||
            schema.traits.find { |trait| trait.name == name }
        end
      end
    end
  end
end
