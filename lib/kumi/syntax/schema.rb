# frozen_string_literal: true

module Kumi
  module Syntax
    # Represents the root of the Abstract Syntax Tree.
    # It holds all the top-level declarations parsed from the source.
    Schema = Struct.new(:attributes, :traits) do
      include Node
      def children = [attributes, traits]
    end
  end
end
