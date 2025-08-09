# frozen_string_literal: true

module Kumi
  module Syntax
    # Represents the root of the Abstract Syntax Tree.
    # It holds all the top-level declarations parsed from the source.
    Root = Struct.new(:inputs, :values, :traits) do
      include Node

      def children = [inputs, values, traits]
    end
  end
end
