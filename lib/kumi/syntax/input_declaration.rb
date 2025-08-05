# frozen_string_literal: true

module Kumi
  module Syntax
    # For field metadata declarations inside input blocks
    InputDeclaration = Struct.new(:name, :domain, :type, :children, :access_mode) do
      include Node

      def children = self[:children] || []
      def access_mode = self[:access_mode]
    end
  end
end
