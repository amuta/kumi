# frozen_string_literal: true

# RESPONSIBILITY
#   Compute :topo_order from :dependency_graph.
# INTERFACE
#   new(schema, state).run(errors)  (errors unused)

module Kumi
  module Analyzer
    module Passes
      class Toposorter
        def initialize(_schema, state)
          @state = state
        end

        def run(errors)
          g = @state[:dependency_graph] || {}
          temp = Set.new
          perm = Set.new
          order = []
          visit = lambda do |n|
            return if perm.include?(n)

            if temp.include?(n)
              errors << [:cycle, "cycle detected: #{temp.to_a.join(' → ')} → #{n}"]
              return
            end

            temp << n
            Array(g[n]).each { |m| visit.call(m) }
            temp.delete(n)
            perm << n
            order << n
          end
          g.each_key { |n| visit.call(n) }
          @state[:topo_order] = order
        end
      end
    end
  end
end
