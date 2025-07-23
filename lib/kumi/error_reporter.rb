# frozen_string_literal: true

module Kumi
  # Centralized error reporting interface for consistent location handling
  # and error message formatting across the entire codebase.
  #
  # This module provides a unified way to:
  # 1. Report errors with consistent location information
  # 2. Format error messages uniformly
  # 3. Handle missing location data gracefully
  # 4. Support both immediate raising and error accumulation patterns
  module ErrorReporter
    # Standard error structure for internal use
    ErrorEntry = Struct.new(:location, :message, :type, :context, keyword_init: true) do
      def to_s
        location_str = format_location(location)
        "#{location_str}: #{message}"
      end

      def has_location?
        location && !location.is_a?(Symbol)
      end

      private

      def format_location(loc)
        case loc
        when nil
          "at ?"
        when Symbol
          "at #{loc}"
        when Syntax::Location
          "at #{loc.file}:#{loc.line}:#{loc.column}"
        else
          "at #{loc}"
        end
      end
    end

    module_function

    # Create a standardized error entry
    #
    # @param message [String] The error message
    # @param location [Syntax::Location, Symbol, nil] Location information
    # @param type [Symbol] Optional error category (:syntax, :semantic, :type, etc.)
    # @param context [Hash] Optional additional context
    # @return [ErrorEntry] Structured error entry
    def create_error(message, location: nil, type: :semantic, context: {})
      ErrorEntry.new(
        location: location,
        message: message,
        type: type,
        context: context
      )
    end

    # Add an error to an accumulator array (for analyzer passes)
    #
    # @param errors [Array] Error accumulator array
    # @param message [String] The error message
    # @param location [Syntax::Location, Symbol, nil] Location information
    # @param type [Symbol] Error category
    # @param context [Hash] Additional context
    def add_error(errors, message, location: nil, type: :semantic, context: {})
      entry = create_error(message, location: location, type: type, context: context)
      errors << entry
      entry
    end

    # Immediately raise a localized error (for parser)
    #
    # @param message [String] The error message
    # @param location [Syntax::Location, Symbol, nil] Location information
    # @param error_class [Class] Exception class to raise
    # @param type [Symbol] Error category
    # @param context [Hash] Additional context
    def raise_error(message, location: nil, error_class: Errors::SemanticError, type: :semantic, context: {})
      entry = create_error(message, location: location, type: type, context: context)
      # Pass both the formatted message and the original location to the error constructor
      raise error_class.new(entry.to_s, location)
    end

    # Format multiple errors into a single message
    #
    # @param errors [Array<ErrorEntry>] Array of error entries
    # @return [String] Formatted error message
    def format_errors(errors)
      errors.map(&:to_s).join("\n")
    end

    # Group errors by type for better organization
    #
    # @param errors [Array<ErrorEntry>] Array of error entries
    # @return [Hash] Errors grouped by type
    def group_errors_by_type(errors)
      errors.group_by(&:type)
    end

    # Check if any errors lack location information
    #
    # @param errors [Array<ErrorEntry>] Array of error entries
    # @return [Array<ErrorEntry>] Errors without location info
    def missing_location_errors(errors)
      errors.reject(&:has_location?)
    end

    # Enhanced error reporting with suggestions and context
    #
    # @param message [String] Base error message
    # @param location [Syntax::Location, nil] Location information
    # @param suggestions [Array<String>] Suggested fixes
    # @param similar_names [Array<String>] Similar names for typo suggestions
    # @param type [Symbol] Error category
    # @return [ErrorEntry] Enhanced error entry
    def create_enhanced_error(message, location: nil, suggestions: [], similar_names: [], type: :semantic)
      enhanced_message = build_enhanced_message(message, suggestions, similar_names)
      create_error(enhanced_message, location: location, type: type, context: {
                     suggestions: suggestions,
                     similar_names: similar_names
                   })
    end

    # Validate that location information is present where expected
    #
    # @param errors [Array<ErrorEntry>] Array of error entries
    # @param expected_with_location [Array<Symbol>] Error types that should have locations
    # @return [Hash] Validation report
    def validate_error_locations(errors, expected_with_location: %i[syntax semantic type])
      report = {
        total_errors: errors.size,
        errors_with_location: errors.count(&:has_location?),
        errors_without_location: errors.reject(&:has_location?),
        location_coverage: 0.0
      }

      report[:location_coverage] = (report[:errors_with_location].to_f / report[:total_errors]) * 100 if report[:total_errors].positive?

      # Check specific types that should have locations
      report[:problematic_errors] = errors.select do |error|
        expected_with_location.include?(error.type) && !error.has_location?
      end

      report
    end

    private

    def build_enhanced_message(base_message, suggestions, similar_names)
      parts = [base_message]

      parts << "Did you mean: #{similar_names.map { |name| "`#{name}`" }.join(', ')}?" unless similar_names.empty?

      unless suggestions.empty?
        parts << "Suggestions:"
        suggestions.each { |suggestion| parts << "  - #{suggestion}" }
      end

      parts.join("\n")
    end

    module_function :build_enhanced_message
  end
end
