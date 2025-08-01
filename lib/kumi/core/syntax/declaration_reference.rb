# frozen_string_literal: true

module Kumi
  module Core
    module Syntax
      DeclarationReference = Struct.new(:name) do
        include Node

        def children = []
      end
    end
  end
end
