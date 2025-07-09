# frozen_string_literal: true

module Kumi
  # Registry for functions that can be used in Kumi schemas
  # This is the public interface for registering custom functions
  module FunctionRegistry
    class UnknownFunction < StandardError; end

    # Core operators that are always available
    CORE_OPERATORS = %i[== > < >= <= !=].freeze

    # Function entry with metadata
    Entry = Struct.new(:fn, :arity, :types, :description, keyword_init: true)

    # Core comparison operators
    CORE_OPERATORS_PROCS = {
      :== => Entry.new(
        fn: ->(a, b) { a == b },
        arity: 2,
        types: %i[any any],
        description: "Equality comparison"
      ),
      :!= => Entry.new(
        fn: ->(a, b) { a != b },
        arity: 2,
        types: %i[any any],
        description: "Inequality comparison"
      ),
      :> => Entry.new(
        fn: ->(a, b) { a > b },
        arity: 2,
        types: %i[numeric numeric],
        description: "Greater than comparison"
      ),
      :< => Entry.new(
        fn: ->(a, b) { a < b },
        arity: 2,
        types: %i[numeric numeric],
        description: "Less than comparison"
      ),
      :>= => Entry.new(
        fn: ->(a, b) { a >= b },
        arity: 2,
        types: %i[numeric numeric],
        description: "Greater than or equal comparison"
      ),
      :<= => Entry.new(
        fn: ->(a, b) { a <= b },
        arity: 2,
        types: %i[numeric numeric],
        description: "Less than or equal comparison"
      )
    }.freeze

    # Core mathematical operations
    MATH_OPERATIONS = {
      add: Entry.new(
        fn: ->(a, b) { a + b },
        arity: 2,
        types: %i[numeric numeric],
        description: "Add two numbers"
      ),
      subtract: Entry.new(
        fn: ->(a, b) { a - b },
        arity: 2,
        types: %i[numeric numeric],
        description: "Subtract second number from first"
      ),
      multiply: Entry.new(
        fn: ->(a, b) { a * b },
        arity: 2,
        types: %i[numeric numeric],
        description: "Multiply two numbers"
      ),
      divide: Entry.new(
        fn: ->(a, b) { a / b },
        arity: 2,
        types: %i[numeric numeric],
        description: "Divide first number by second"
      ),
      modulo: Entry.new(
        fn: ->(a, b) { a % b },
        arity: 2,
        types: %i[numeric numeric],
        description: "Modulo operation"
      ),
      power: Entry.new(
        fn: ->(a, b) { a**b },
        arity: 2,
        types: %i[numeric numeric],
        description: "Raise first number to power of second"
      ),
      abs: Entry.new(
        fn: lambda(&:abs),
        arity: 1,
        types: %i[numeric],
        description: "Absolute value"
      ),
      round: Entry.new(
        fn: ->(a, precision = 0) { a.round(precision) },
        arity: -1, # Variable arity
        types: %i[numeric],
        description: "Round number to specified precision"
      ),
      floor: Entry.new(
        fn: lambda(&:floor),
        arity: 1,
        types: %i[numeric],
        description: "Floor of number"
      ),
      ceil: Entry.new(
        fn: lambda(&:ceil),
        arity: 1,
        types: %i[numeric],
        description: "Ceiling of number"
      ),
      clamp: Entry.new(
        fn: ->(value, min, max) { [[value, min].max, max].min },
        arity: 3,
        types: %i[numeric numeric numeric],
        description: "Clamp value between min and max"
      )
    }.freeze

    # Core string operations
    STRING_OPERATIONS = {
      concat: Entry.new(
        fn: ->(*strings) { strings.join },
        arity: -1, # Variable arity
        types: %i[string],
        description: "Concatenate multiple strings"
      ),
      upcase: Entry.new(
        fn: ->(str) { str.to_s.upcase },
        arity: 1,
        types: %i[string],
        description: "Convert string to uppercase"
      ),
      downcase: Entry.new(
        fn: ->(str) { str.to_s.downcase },
        arity: 1,
        types: %i[string],
        description: "Convert string to lowercase"
      ),
      capitalize: Entry.new(
        fn: ->(str) { str.to_s.capitalize },
        arity: 1,
        types: %i[string],
        description: "Capitalize first letter of string"
      ),
      strip: Entry.new(
        fn: ->(str) { str.to_s.strip },
        arity: 1,
        types: %i[string],
        description: "Remove leading and trailing whitespace"
      ),
      length: Entry.new(
        fn: ->(str) { str.to_s.length },
        arity: 1,
        types: %i[string],
        description: "Get string length"
      ),
      include?: Entry.new(
        fn: ->(str, substr) { str.to_s.include?(substr.to_s) },
        arity: 2,
        types: %i[string string],
        description: "Check if string contains substring"
      ),
      start_with?: Entry.new(
        fn: ->(str, prefix) { str.to_s.start_with?(prefix.to_s) },
        arity: 2,
        types: %i[string string],
        description: "Check if string starts with prefix"
      ),
      end_with?: Entry.new(
        fn: ->(str, suffix) { str.to_s.end_with?(suffix.to_s) },
        arity: 2,
        types: %i[string string],
        description: "Check if string ends with suffix"
      )
    }.freeze

    # Core logical operations
    LOGICAL_OPERATIONS = {
      and: Entry.new(
        fn: ->(*conditions) { conditions.all? },
        arity: -1, # Variable arity
        types: %i[boolean],
        description: "Logical AND of multiple conditions"
      ),
      or: Entry.new(
        fn: ->(*conditions) { conditions.any? },
        arity: -1, # Variable arity
        types: %i[boolean],
        description: "Logical OR of multiple conditions"
      ),
      not: Entry.new(
        fn: lambda(&:!),
        arity: 1,
        types: %i[boolean],
        description: "Logical NOT"
      ),
      all?: Entry.new(
        fn: lambda(&:all?),
        arity: 1,
        types: %i[collection],
        description: "Check if all elements in collection are truthy"
      ),
      any?: Entry.new(
        fn: lambda(&:any?),
        arity: 1,
        types: %i[collection],
        description: "Check if any element in collection is truthy"
      ),
      none?: Entry.new(
        fn: lambda(&:none?),
        arity: 1,
        types: %i[collection],
        description: "Check if no elements in collection are truthy"
      )
    }.freeze

    # Core collection operations
    COLLECTION_OPERATIONS = {
      size: Entry.new(
        fn: lambda(&:size),
        arity: 1,
        types: %i[collection],
        description: "Get collection size"
      ),
      empty?: Entry.new(
        fn: lambda(&:empty?),
        arity: 1,
        types: %i[collection],
        description: "Check if collection is empty"
      ),
      first: Entry.new(
        fn: lambda(&:first),
        arity: 1,
        types: %i[collection],
        description: "Get first element of collection"
      ),
      last: Entry.new(
        fn: lambda(&:last),
        arity: 1,
        types: %i[collection],
        description: "Get last element of collection"
      ),
      sum: Entry.new(
        fn: lambda(&:sum),
        arity: 1,
        types: %i[collection],
        description: "Sum all elements in collection"
      ),
      max: Entry.new(
        fn: lambda(&:max),
        arity: 1,
        types: %i[collection],
        description: "Get maximum value in collection"
      ),
      min: Entry.new(
        fn: lambda(&:min),
        arity: 1,
        types: %i[collection],
        description: "Get minimum value in collection"
      ),
      sort: Entry.new(
        fn: lambda(&:sort),
        arity: 1,
        types: %i[collection],
        description: "Sort collection"
      ),
      reverse: Entry.new(
        fn: lambda(&:reverse),
        arity: 1,
        types: %i[collection],
        description: "Reverse collection"
      ),
      uniq: Entry.new(
        fn: lambda(&:uniq),
        arity: 1,
        types: %i[collection],
        description: "Remove duplicates from collection"
      )
    }.freeze

    # Core conditional operations
    CONDITIONAL_OPERATIONS = {
      conditional: Entry.new(
        fn: ->(condition, true_value, false_value) { condition ? true_value : false_value },
        arity: 3,
        types: %i[boolean any any],
        description: "Ternary conditional operator"
      ),
      if: Entry.new(
        fn: ->(condition, true_value, false_value = nil) { condition ? true_value : false_value },
        arity: -1, # Variable arity (2 or 3)
        types: %i[boolean any any],
        description: "If-then-else conditional"
      ),
      coalesce: Entry.new(
        fn: ->(*values) { values.find { |v| !v.nil? } },
        arity: -1, # Variable arity
        types: %i[any],
        description: "Return first non-nil value"
      ),
      else: Entry.new(
        fn: ->(value, else_value) { value.nil? ? else_value : value },
        arity: 2,
        types: %i[any any],
        description: "Provide else value if first is nil"
      )
    }.freeze

    # Core type conversion operations
    TYPE_OPERATIONS = {
      to_string: Entry.new(
        fn: lambda(&:to_s),
        arity: 1,
        types: %i[any],
        description: "Convert value to string"
      ),
      to_integer: Entry.new(
        fn: lambda(&:to_i),
        arity: 1,
        types: %i[any],
        description: "Convert value to integer"
      ),
      to_float: Entry.new(
        fn: lambda(&:to_f),
        arity: 1,
        types: %i[any],
        description: "Convert value to float"
      ),
      to_boolean: Entry.new(
        fn: ->(value) { !value.nil? },
        arity: 1,
        types: %i[any],
        description: "Convert value to boolean"
      ),
      to_array: Entry.new(
        fn: ->(value) { Array(value) },
        arity: 1,
        types: %i[any],
        description: "Convert value to array"
      )
    }.freeze

    # Combine all core operations
    CORE_OPERATIONS = {
      **CORE_OPERATORS_PROCS,
      **MATH_OPERATIONS,
      **STRING_OPERATIONS,
      **LOGICAL_OPERATIONS,
      **COLLECTION_OPERATIONS,
      **CONDITIONAL_OPERATIONS,
      **TYPE_OPERATIONS
    }.freeze

    @functions = CORE_OPERATIONS.dup

    class << self
      # Public interface for registering custom functions
      def register(name, &block)
        raise ArgumentError, "Function #{name.inspect} already registered" if @functions.key?(name)

        fn_lambda = block.is_a?(Proc) ? block : ->(*args) { yield(*args) }
        register_with_metadata(name, fn_lambda, arity: fn_lambda.arity, types: [:any])
      end

      # Register with custom metadata
      def register_with_metadata(name, fn_lambda, arity:, types: [:any], description: nil)
        raise ArgumentError, "Function #{name.inspect} already registered" if @functions.key?(name)

        @functions[name] = Entry.new(
          fn: fn_lambda,
          arity: arity,
          types: types,
          description: description
        )
      end

      # Check if a function is a core operator
      def operator?(name)
        return false unless name.is_a?(Symbol)

        @functions.key?(name) && CORE_OPERATORS.include?(name)
      end

      # Get function by name
      def fetch(name)
        entry = @functions[name]
        confirm_support!(name)
        entry.fn
      end

      # Get function signature
      def signature(name)
        confirm_support!(name)
        entry = @functions[name]
        { arity: entry.arity, types: entry.types, description: entry.description }
      end

      # Check if function is supported
      def supported?(name)
        @functions.key?(name)
      end

      # Get all registered function names
      def all
        @functions.keys
      end

      # Get all functions with their metadata
      def all_with_metadata
        @functions.transform_values { |entry| signature(entry) }
      end

      # Get functions by category
      def operators
        @functions.slice(*CORE_OPERATORS)
      end

      def math_operations
        @functions.select { |name, _| MATH_OPERATIONS.key?(name) }
      end

      def string_operations
        @functions.select { |name, _| STRING_OPERATIONS.key?(name) }
      end

      def logical_operations
        @functions.select { |name, _| LOGICAL_OPERATIONS.key?(name) }
      end

      def collection_operations
        @functions.select { |name, _| COLLECTION_OPERATIONS.key?(name) }
      end

      def conditional_operations
        @functions.select { |name, _| CONDITIONAL_OPERATIONS.key?(name) }
      end

      def type_operations
        @functions.select { |name, _| TYPE_OPERATIONS.key?(name) }
      end

      # Reset to core operations only
      def reset!
        @functions.clear
        @functions.merge!(CORE_OPERATIONS)
      end

      # Freeze the registry
      def freeze
        @functions.freeze
        super
      end

      # Auto-register functions from a module
      def auto_register(module_name, prefix: nil)
        module_obj = Object.const_get(module_name)

        module_obj.instance_methods(false).each do |method_name|
          function_name = prefix ? :"#{prefix}_#{method_name}" : method_name

          # Skip if already registered
          next if @functions.key?(function_name)

          # Create a wrapper that calls the module method
          wrapper = ->(*args) { module_obj.public_send(method_name, *args) }

          # Try to get method arity
          method = module_obj.instance_method(method_name)
          arity = method.arity

          register_with_metadata(
            function_name,
            wrapper,
            arity: arity,
            types: [:any],
            description: "Auto-registered from #{module_name}##{method_name}"
          )
        end
      end

      private

      def confirm_support!(name)
        raise UnknownFunction, "Unknown function: '#{name.inspect}'" unless supported?(name)
      end
    end
  end
end
