# frozen_string_literal: true

module Kumi
  module Errors
    class Error < StandardError; end

    class LocatedError < Error
      attr_reader :location

      def initialize(message, location = nil)
        super(message)
        @location = location
      end

      def to_s
        if @location
          "#{super} at #{@location.file}:#{@location.line}:#{@location.column}"
        else
          super
        end
      end
    end

    class SemanticError < LocatedError; end

    class TypeError < SemanticError; end

    class SyntaxError < LocatedError; end

    class RuntimeError < Error; end
  end
end
