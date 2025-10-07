# frozen_string_literal: true

module Kumi
  module Syntax
    # For field metadata declarations inside input blocks
    InputDeclaration = Struct.new(:name, :domain, :type, :children, :index) do
      include Node

      def children = self[:children] || []
      def index = self[:index]
    end
  end
end
