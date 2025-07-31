# frozen_string_literal: true

module Kumi
  # Mixin module providing error reporting capabilities to classes
  # that need to report localized errors consistently.
  #
  # Usage:
  #   class MyAnalyzer
  #     include ErrorReporting
  #
  #     def analyze(errors)
  #       report_error(errors, "Something went wrong", location: some_location)
  #       raise_localized_error("Critical error", location: some_location)
  #     end
  #   end
  module ErrorReporting
    # Report an error to an accumulator (analyzer pattern)
    #
    # @param errors [Array] Error accumulator array
    # @param message [String] Error message
    # @param location [Syntax::Location, Symbol, nil] Location info
    # @param type [Symbol] Error category (:syntax, :semantic, :type, etc.)
    # @param context [Hash] Additional context
    # @return [ErrorReporter::ErrorEntry] The created error entry
    def report_error(errors, message, location: nil, type: :semantic, context: {})
      ErrorReporter.add_error(errors, message, location: location, type: type, context: context)
    end

    # Immediately raise a localized error (parser pattern)
    #
    # @param message [String] Error message
    # @param location [Syntax::Location, Symbol, nil] Location info
    # @param error_class [Class] Exception class to raise
    # @param type [Symbol] Error category
    # @param context [Hash] Additional context
    def raise_localized_error(message, location: nil, error_class: Errors::SemanticError, type: :semantic, context: {})
      ErrorReporter.raise_error(message, location: location, error_class: error_class, type: type, context: context)
    end

    # Report a syntax error to an accumulator
    def report_syntax_error(errors, message, location: nil, context: {})
      report_error(errors, message, location: location, type: :syntax, context: context)
    end

    # Report a type error to an accumulator
    def report_type_error(errors, message, location: nil, context: {})
      report_error(errors, message, location: location, type: :type, context: context)
    end

    # Report a semantic error to an accumulator
    def report_semantic_error(errors, message, location: nil, context: {})
      report_error(errors, message, location: location, type: :semantic, context: context)
    end

    # Immediately raise a syntax error
    def raise_syntax_error(message, location: nil, context: {})
      raise_localized_error(message, location: location, error_class: Kumi::Errors::SyntaxError, type: :syntax, context: context)
    end

    # Immediately raise a type error
    def raise_type_error(message, location: nil, context: {})
      raise_localized_error(message, location: location, error_class: Errors::TypeError, type: :type, context: context)
    end

    # Create an enhanced error with suggestions
    #
    # @param errors [Array] Error accumulator array
    # @param message [String] Base error message
    # @param location [Syntax::Location, nil] Location info
    # @param suggestions [Array<String>] Suggested fixes
    # @param similar_names [Array<String>] Similar names for typos
    # @param type [Symbol] Error category
    def report_enhanced_error(errors, message, location: nil, suggestions: [], similar_names: [], type: :semantic)
      entry = ErrorReporter.create_enhanced_error(
        message,
        location: location,
        suggestions: suggestions,
        similar_names: similar_names,
        type: type
      )
      errors << entry
      entry
    end

    # Get current location from caller stack (fallback method)
    #
    # @return [Syntax::Location] Location based on caller stack
    def inferred_location
      fallback = caller_locations.find(&:absolute_path)
      return nil unless fallback

      Syntax::Location.new(file: fallback.path, line: fallback.lineno, column: 0)
    end
  end
end
