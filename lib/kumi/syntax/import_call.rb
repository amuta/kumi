# frozen_string_literal: true

module Kumi
  module Syntax
    ImportCall = Struct.new(:fn_name, :input_mapping, :loc) do
      include Node

      def children = input_mapping.values
    end
  end
end
