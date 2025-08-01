# frozen_string_literal: true

module Kumi
  # Metadata system for vectorization detection and handling
  module VectorizationMetadata
    # Tracks which declarations are arrays with children (vectorizable)
    class ArrayDeclarationTracker
      def initialize
        @array_declarations = {}
      end

      def register_array(name, children)
        @array_declarations[name] = children.map(&:name)
      end

      def array_declaration?(name)
        @array_declarations.key?(name)
      end

      def array_children(name)
        @array_declarations[name] || []
      end

      def all_arrays
        @array_declarations.keys
      end
    end

    # Detects vectorized operations in expressions
    class VectorizationDetector
      def initialize(array_tracker)
        @array_tracker = array_tracker
      end

      # Check if an expression should be vectorized
      def vectorized_expression?(expression)
        case expression
        when Kumi::Syntax::CallExpression
          vectorized_call?(expression)
        when Kumi::Syntax::InputElementReference
          vectorized_element_reference?(expression)
        else
          false
        end
      end

      # Check if a function call should be treated as a reducer
      def reducer_function?(fn_name, args)
        REDUCER_FUNCTIONS.include?(fn_name) &&
          args.any? { |arg| vectorized_expression?(arg) }
      end

      private

      REDUCER_FUNCTIONS = %i[sum min max size length first last].freeze

      def vectorized_call?(call_expr)
        # Arithmetic operations between array elements are vectorized
        ARITHMETIC_OPERATIONS.include?(call_expr.fn_name) &&
          call_expr.args.any? { |arg| vectorized_expression?(arg) }
      end

      def vectorized_element_reference?(elem_ref)
        return false unless elem_ref.path.size >= 2

        array_name, _field_name = elem_ref.path
        @array_tracker.array_declaration?(array_name)
      end

      ARITHMETIC_OPERATIONS = %i[add subtract multiply divide modulo power].freeze
    end

    # Metadata about how values should be computed
    class ComputationMetadata
      attr_reader :vectorized_values, :reducer_values, :scalar_values

      def initialize
        @vectorized_values = Set.new
        @reducer_values = Set.new
        @scalar_values = Set.new
      end

      def mark_vectorized(name)
        @vectorized_values.add(name)
      end

      def mark_reducer(name)
        @reducer_values.add(name)
      end

      def mark_scalar(name)
        @scalar_values.add(name)
      end

      def vectorized?(name)
        @vectorized_values.include?(name)
      end

      def reducer?(name)
        @reducer_values.include?(name)
      end

      def scalar?(name)
        @scalar_values.include?(name)
      end
    end
  end
end
