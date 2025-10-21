# frozen_string_literal: true

module Kumi
  module Core
    module Functions
      # TypeErrorReporter provides typed error reporting for function resolution and type checking
      # Ensures all type errors have proper location information for better diagnostics
      module TypeErrorReporter
        # Report function overload resolution failure with proper location
        #
        # @param errors [Array] Error accumulator
        # @param alias_or_id [String, Symbol] Function alias or ID that couldn't be resolved
        # @param arg_types [Array<Symbol>] Argument types that didn't match any overload
        # @param available_overloads [Array<String>] Available function overload IDs
        # @param location [Syntax::Location, nil] Where the error occurred
        def self.report_overload_resolution_error(errors, alias_or_id, arg_types, available_overloads, location)
          message = format_overload_error(alias_or_id, arg_types, available_overloads)

          error = Core::ErrorReporter.create_error(
            message,
            location: location,
            type: :type,
            context: {
              alias: alias_or_id.to_s,
              arg_types: arg_types,
              candidates: available_overloads
            }
          )

          errors << error
          error
        end

        # Report arity mismatch (wrong number of arguments)
        #
        # @param errors [Array] Error accumulator
        # @param fn_id [String] Full function ID
        # @param expected [Integer] Expected number of arguments
        # @param actual [Integer] Actual number of arguments provided
        # @param location [Syntax::Location, nil] Where the error occurred
        def self.report_arity_mismatch(errors, fn_id, expected, actual, location)
          message = "function '#{fn_id}' expects #{expected} argument(s), got #{actual}"

          error = Core::ErrorReporter.create_error(
            message,
            location: location,
            type: :type,
            context: {
              function: fn_id.to_s,
              expected: expected,
              actual: actual
            }
          )

          errors << error
          error
        end

        # Report type constraint violation (parameter type doesn't match argument type)
        #
        # @param errors [Array] Error accumulator
        # @param fn_id [String] Full function ID
        # @param param_name [String] Parameter name
        # @param expected_type [String] Expected type constraint
        # @param actual_type [Symbol] Actual argument type
        # @param location [Syntax::Location, nil] Where the error occurred
        def self.report_type_constraint_violation(errors, fn_id, param_name, expected_type, actual_type, location)
          message = "function '#{fn_id}' parameter '#{param_name}' expects type #{expected_type.inspect}, " \
                    "got #{actual_type.inspect}"

          error = Core::ErrorReporter.create_error(
            message,
            location: location,
            type: :type,
            context: {
              function: fn_id.to_s,
              parameter: param_name.to_s,
              expected_type: expected_type.to_s,
              actual_type: actual_type.to_s
            }
          )

          errors << error
          error
        end

        # Report unknown function
        #
        # @param errors [Array] Error accumulator
        # @param alias_or_id [String, Symbol] Function name/alias that doesn't exist
        # @param location [Syntax::Location, nil] Where the error occurred
        def self.report_unknown_function(errors, alias_or_id, location)
          message = "unknown function '#{alias_or_id}'"

          error = Core::ErrorReporter.create_error(
            message,
            location: location,
            type: :semantic,
            context: { function: alias_or_id.to_s }
          )

          errors << error
          error
        end

        def self.format_overload_error(alias_or_id, arg_types, available_overloads)
          arg_types_str = arg_types.map(&:inspect).join(", ")
          available_str = available_overloads.map { |id| "'#{id}'" }.join(", ")

          "no overload of '#{alias_or_id}' matches argument types (#{arg_types_str}). " \
            "Available overloads: #{available_str}"
        end
      end
    end
  end
end
