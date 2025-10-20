# frozen_string_literal: true

module Kumi
  module Core
    module Errors
      class Error < StandardError; end

      class LocatedError < Error
        attr_reader :location

        def initialize(message, location = nil)
          super(message)
          @location = location
        end

        # Extract location components cleanly
        def location_file
          @location&.file
        end

        def location_line
          @location&.line
        end

        def location_column
          @location&.column
        end

        # Aliases for convenient access
        alias path location_file
        alias line location_line
        alias column location_column

        # Check if location information is present and valid
        def has_location?
          @location && @location.file && @location.line && @location.line > 0
        end

        # Format location for error messages
        def format_location
          if @location
            "at #{@location.file} line=#{@location.line} column=#{@location.column}"
          else
            "at ?"
          end
        end

        def to_s
          if @location
            "#{super} #{format_location}"
          else
            super
          end
        end
      end

      class UnknownFunction < Error; end

      class AnalysisError < Error; end

      class SemanticError < LocatedError; end

      class TypeError < SemanticError; end

      class FieldMetadataError < SemanticError; end

      class SyntaxError < LocatedError; end

      class CompilationError < Error; end

      class RuntimeError < Error; end

      class DomainViolationError < Error
        attr_reader :violations

        def initialize(violations)
          @violations = violations
          super(format_message)
        end

        def single_violation?
          violations.size == 1
        end

        def multiple_violations?
          violations.size > 1
        end

        private

        def format_message
          if single_violation?
            violations.first[:message]
          else
            "Multiple domain violations:\n#{violations.map { |v| "  - #{v[:message]}" }.join("\n")}"
          end
        end
      end

      class InputValidationError < Error
        attr_reader :violations

        def initialize(violations)
          @violations = violations
          super(format_message)
        end

        def single_violation?
          violations.size == 1
        end

        def multiple_violations?
          violations.size > 1
        end

        def type_violations
          violations.select { |v| v[:type] == :type_violation }
        end

        def domain_violations
          violations.select { |v| v[:type] == :domain_violation }
        end

        def type_violations?
          type_violations.any?
        end

        def domain_violations?
          domain_violations.any?
        end

        private

        def format_message
          if single_violation?
            violations.first[:message]
          else
            message_parts = []

            if type_violations?
              message_parts << "Type violations:"
              type_violations.each { |v| message_parts << "  - #{v[:message]}" }
            end

            if domain_violations?
              message_parts << "Domain violations:"
              domain_violations.each { |v| message_parts << "  - #{v[:message]}" }
            end

            message_parts.join("\n")
          end
        end
      end
    end
  end
end
