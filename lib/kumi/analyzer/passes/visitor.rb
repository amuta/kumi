# frozen_string_literal: true

# RESPONSIBILITY
#   DFS traversal used by other passes.
# INTERFACE
#   visit(node) { |n| … }
module Kumi
  module Analyzer
    module Passes
      class Visitor
        def visit(node, &blk)
          return unless node

          yield(node)
          node.children.each { |c| visit(c, &blk) }
        end
      end
    end
  end
end
