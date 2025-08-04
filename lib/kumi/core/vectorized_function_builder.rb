# frozen_string_literal: true

module Kumi
  module Core
    # Builds vectorized function execution lambdas from analysis metadata
    class VectorizedFunctionBuilder
      include NestedStructureUtils

      def self.build_executor(fn_name, compilation_meta, analysis_state)
        new(fn_name, compilation_meta, analysis_state).build
      end

      def initialize(fn_name, compilation_meta, analysis_state)
        @fn_name = fn_name
        @compilation_meta = compilation_meta
        @analysis_state = analysis_state
      end

      def build
        # Get the function from registry
        fn = Kumi::Registry.fetch(@fn_name)
        
        lambda do |arg_values, loc|
          # Check if any argument is vectorized (array)
          has_vectorized_args = arg_values.any?(Array)

          if has_vectorized_args
            # Apply function with broadcasting to all vectorized arguments
            vectorized_function_call(fn, arg_values)
          else
            # All arguments are scalars - regular function call
            fn.call(*arg_values)
          end
        rescue StandardError => e
          enhanced_message = "Error calling fn(:#{@fn_name}) at #{loc}: #{e.message}"
          runtime_error = Errors::RuntimeError.new(enhanced_message)
          runtime_error.set_backtrace(e.backtrace)
          runtime_error.define_singleton_method(:cause) { e }
          raise runtime_error
        end
      end

      private

      def vectorized_function_call(fn, values)
        # Find array dimensions for broadcasting
        array_values = values.select { |v| v.is_a?(Array) }
        return fn.call(*values) if array_values.empty?

        # Check if we have deeply nested arrays (arrays containing arrays)
        has_nested_arrays = array_values.any? { |arr| arr.is_a?(Array) && arr.first.is_a?(Array) }

        if has_nested_arrays
          # Use recursive element-wise operation for nested arrays
          apply_function_to_nested_structure(fn, values)
        else
          # Original flat array logic
          array_length = array_values.first.size
          (0...array_length).map do |i|
            element_args = values.map do |v|
              v.is_a?(Array) ? v[i] : v # Broadcast scalars
            end
            fn.call(*element_args)
          end
        end
      end

      def apply_function_to_nested_structure(fn, values)
        # Find the first array to determine structure
        array_value = values.find { |v| v.is_a?(Array) }

        # Apply function element-wise, preserving nested structure
        map_nested_structure(array_value) do |*indices|
          element_args = values.map do |value|
            if value.is_a?(Array)
              # Navigate to the corresponding element in nested structure
              navigate_nested_indices(value, indices)
            else
              # Scalar - broadcast to all positions
              value
            end
          end
          fn.call(*element_args)
        end
      end

    end
  end
end