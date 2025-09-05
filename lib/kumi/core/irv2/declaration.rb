# frozen_string_literal: true

require "set"

module Kumi
  module Core
    module IRV2
      class Declaration
        attr_reader :name, :operations, :result, :parameters

        def initialize(name, operations, result, parameters = [])
          @name = name
          @operations = operations
          @result = result
          @parameters = parameters
        end

        def inputs
          @parameters.select { |p| p[:type] == :input }
        end

        def dependencies
          @parameters.select { |p| p[:type] == :dependency }.map { |p| p[:source] }
        end
      end
    end
  end
end
