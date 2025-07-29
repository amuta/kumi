# frozen_string_literal: true

module Kumi
  module Syntax
    # For field metadata declarations inside input blocks
    InputDeclaration = Struct.new(:name, :domain, :type) do
      include Node

      def children = []
    end
  end
end
