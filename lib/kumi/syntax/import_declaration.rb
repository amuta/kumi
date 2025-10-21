# frozen_string_literal: true

module Kumi
  module Syntax
    ImportDeclaration = Struct.new(:names, :module_ref, :loc) do
      include Node

      def children = []
    end
  end
end
