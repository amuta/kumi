# frozen_string_literal: true

module Kumi
  module Syntax
    # For field usage/reference in expressions (input.field_name)
    InputElementReference = Struct.new(:path) do
      include Node

      def children = []
    end
  end
end
