# frozen_string_literal: true

module Kumi
  module Syntax
    # For field usage/reference in expressions (input.field_name)
    InputReference = Struct.new(:name) do
      include Node

      def children = []
    end
  end
end
