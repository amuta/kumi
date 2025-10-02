# frozen_string_literal: true

module Kumi
  module Syntax
    CallExpression = Struct.new(:fn_name, :args, :opts) do
      include Node

      def children = args
    end
  end
end
