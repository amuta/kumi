# frozen_string_literal: true

module Kumi::Core
  module Syntax
    # Represents the root of the Abstract Syntax Tree.
    # It holds all the top-level declarations parsed from the source.
    Root = Struct.new(:inputs, :attributes, :traits) do
      include Node

      def children = [inputs, attributes, traits]
    end
  end
end
