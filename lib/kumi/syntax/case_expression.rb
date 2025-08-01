# frozen_string_literal: true

module Kumi
  module Syntax
      CaseExpression = Struct.new(:condition, :result) do
        include Node

        def children = [condition, result]
      end
  end
end
