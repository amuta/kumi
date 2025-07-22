# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      # RESPONSIBILITY: Detect cycles in the dependency graph using depth-first search
      # DEPENDENCIES: :dependency_graph from DependencyResolver
      # PRODUCES: None (validation only)
      # INTERFACE: new(schema, state).run(errors)
      class CycleDetector < PassBase
        MAX_DEPTH = 1000  # Prevent infinite recursion in pathological cases
        
        def run(errors)
          dependency_graph = get_state(:dependency_graph, required: false) || {}
          visited = Set.new
          recursion_stack = []

          dependency_graph.each_key do |node|
            detect_cycles_from(node, dependency_graph, visited, recursion_stack, errors, 0)
          end
        end

        private

        def detect_cycles_from(node, graph, visited, stack, errors, depth)
          return if visited.include?(node)
          
          # Prevent infinite recursion in pathological cases
          if depth > MAX_DEPTH
            add_error(errors, nil, "Cycle detection depth limit exceeded (#{MAX_DEPTH}). Possible infinite recursion in dependency graph.")
            return
          end

          visited << node
          stack << node

          Array(graph[node]).each do |edge|
            target = edge.to

            if stack.include?(target)
              report_cycle(stack + [target], errors)
            else
              detect_cycles_from(target, graph, visited, stack, errors, depth + 1)
            end
          end

          stack.pop
        end

        def report_cycle(cycle_path, errors)
          cycle_description = cycle_path.join(" → ")

          # Try to find the first declaration in the cycle for location info
          # This provides better location information when schema is available
          first_decl = find_declaration_by_name(cycle_path.first)
          location = first_decl&.loc

          # Use old format for backward compatibility with existing tests
          add_error(errors, location, "cycle detected: #{cycle_description}")
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
