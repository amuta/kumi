# frozen_string_literal: true

module Kumi
  module Syntax
      CallExpression = Struct.new(:fn_name, :args) do
        include Node

        def children = args
      end
  end
end
