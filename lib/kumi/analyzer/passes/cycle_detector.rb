# RESPONSIBILITY
#   Detect cycles in :dependency_graph.
# INTERFACE
#   new(schema, state).run(errors)  (schema unused)

module Kumi
  module Analyzer
    module Passes
      class CycleDetector
        def initialize(_schema, state)
          @state = state
        end

        def run(errors)
          g = @state[:dependency_graph] || {}
          visited = Set.new
          stack = []
          g.each_key { |n| dfs(n, g, visited, stack, errors) }
        end

        private

        def dfs(node, g, visited, stack, errors)
          return if visited.include?(node)

          visited << node
          stack   << node
          Array(g[node]).each do |m|
            if stack.include?(m)
              errors << [nil, "cycle detected: #{(stack + [m]).join(' → ')}"]
            else
              dfs(m, g, visited, stack, errors)
            end
          end
          stack.pop
        end
      end
    end
  end
end
