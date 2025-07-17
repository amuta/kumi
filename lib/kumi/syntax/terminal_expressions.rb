# frozen_string_literal: true

require_relative "node"

module Kumi
  module Syntax
    module TerminalExpressions
      # Leaf expressions that represent a value or reference and terminate a branch.

      Literal = Struct.new(:value) do
        include Node
        def children = []
      end
      Field = Struct.new(:name, :domain, :type) do
        include Node
        def children = []
      end
      Binding = Struct.new(:name) do
        include Node
        def children = []
      end
    end
  end
end
