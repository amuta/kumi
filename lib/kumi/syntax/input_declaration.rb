# frozen_string_literal: true

module Kumi
  module Syntax
    # For field metadata declarations inside input blocks
    InputDeclaration = Struct.new(:name, :domain, :type, :children) do
      include Node

      def children = self[:children] || []
    end
  end
end
