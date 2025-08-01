# frozen_string_literal: true

module Kumi
  module Core
    module RubyParser
      class BuildContext
        attr_reader :inputs, :attributes, :traits
        attr_accessor :current_location

        def initialize
          @inputs = []
          @attributes = []
          @traits = []
          @input_block_defined = false
        end

        def input_block_defined?
          @input_block_defined
        end

        def mark_input_block_defined!
          @input_block_defined = true
        end
      end
    end
  end
end
