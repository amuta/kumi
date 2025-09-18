# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Compute topological ordering of declarations, blocking all cycles
        # DEPENDENCIES: :dependencies from DependencyResolver, :declarations from NameIndexer
        # PRODUCES: :evaluation_order - Array of declaration names in evaluation order
        # INTERFACE: new(schema, state).run(errors)
        class Toposorter < PassBase
          def run(errors)
            dependency_graph = get_state(:dependencies, required: false) || {}
            definitions = get_state(:declarations, required: false) || {}

            order = compute_topological_order(dependency_graph, definitions, errors)

            state.with(:evaluation_order, order)
          end

          private

          def compute_topological_order(graph, definitions, errors)
            temp_marks = Set.new
            perm_marks = Set.new
            order = []

            visit_node = lambda do |node, path = []|
              return if perm_marks.include?(node)

              if temp_marks.include?(node)
                # Block all cycles - no mutual recursion allowed
                report_unexpected_cycle(temp_marks, node, errors)
                return
              end

              temp_marks << node
              current_path = path + [node]
              # Only follow edges to other declarations, not to input fields
              # This prevents false cycles when a declaration has the same name as an input
              Array(graph[node]).each do |edge|
                next if edge.type == :key # Skip input field dependencies

                visit_node.call(edge.to, current_path)
              end
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

            report_error(errors, "cycle detected: #{cycle_path}", location: location)
          end

          def find_declaration_by_name(name)
            return nil unless schema

            schema.values.find { |attr| attr.name == name } ||
              schema.traits.find { |trait| trait.name == name }
          end
        end
      end
    end
  end
end
