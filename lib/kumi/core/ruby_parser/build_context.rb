# frozen_string_literal: true

module Kumi
  module Core
    module RubyParser
      class BuildContext
        attr_reader :inputs, :values, :traits, :imports, :imported_names
        attr_accessor :current_location

        def initialize
          @inputs = []
          @values = []
          @traits = []
          @imports = []
          @imported_names = Set.new
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
