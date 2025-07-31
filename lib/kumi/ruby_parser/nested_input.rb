# frozen_string_literal: true

module Kumi
  module RubyParser
    # Simple context struct for nested input collection
    class NestedInput
      attr_reader :inputs, :current_location

      def initialize(inputs_array, location)
        @inputs = inputs_array
        @current_location = location
      end
    end
  end
end
