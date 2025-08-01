# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      # RESPONSIBILITY: Compute topological ordering of declarations, allowing safe conditional cycles
      # DEPENDENCIES: :dependencies from DependencyResolver, :declarations from NameIndexer, :cascades from UnsatDetector
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
          cascades = get_state(:cascades) || {}

          visit_node = lambda do |node, path = []|
            return if perm_marks.include?(node)

            if temp_marks.include?(node)
              # Check if this is a safe conditional cycle
              cycle_path = path + [node]
              if safe_conditional_cycle?(cycle_path, graph, cascades)
                # Allow this cycle - it's safe due to cascade mutual exclusion
                return
              else
                report_unexpected_cycle(temp_marks, node, errors)
                return
              end
            end

            temp_marks << node
            current_path = path + [node]
            Array(graph[node]).each { |edge| visit_node.call(edge.to, current_path) }
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

        def safe_conditional_cycle?(cycle_path, graph, cascades)
          return false if cycle_path.nil? || cycle_path.size < 2
          
          # Find where the cycle starts - look for the first occurrence of the repeated node
          last_node = cycle_path.last
          return false if last_node.nil?
          
          cycle_start = cycle_path.index(last_node)
          return false unless cycle_start && cycle_start < cycle_path.size - 1
          
          cycle_nodes = cycle_path[cycle_start..-1]
          
          # Check if all edges in the cycle are conditional
          cycle_nodes.each_cons(2) do |from, to|
            edges = graph[from] || []
            edge = edges.find { |e| e.to == to }
            
            return false unless edge&.conditional
            
            # Check if the cascade has mutually exclusive conditions
            cascade_meta = cascades[edge.cascade_owner]
            return false unless cascade_meta&.dig(:all_mutually_exclusive)
          end
          
          true
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

          schema.attributes.find { |attr| attr.name == name } ||
            schema.traits.find { |trait| trait.name == name }
        end
      end
    end
  end
end
