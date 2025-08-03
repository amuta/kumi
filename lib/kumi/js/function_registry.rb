# frozen_string_literal: true

module Kumi
  module Js
    # Maps Ruby function registry to JavaScript implementations
    # Each function maintains the same signature and behavior as the Ruby version
    module FunctionRegistry
      # Generate complete JavaScript function registry
      def self.generate_js_registry
        {
          # Mathematical functions
          **math_functions,

          # Comparison functions
          **comparison_functions,

          # Logical functions
          **logical_functions,

          # String functions
          **string_functions,

          # Collection functions
          **collection_functions,

          # Conditional functions
          **conditional_functions,

          # Type functions
          **type_functions
        }
      end

      # Generate JavaScript code for the function registry
      def self.generate_js_code(functions_required: nil)
        registry = generate_js_registry
        
        # Filter registry to only include required functions if specified
        if functions_required && !functions_required.empty?
          registry = registry.select { |name, _| functions_required.include?(name) }
        end

        functions_js = registry.map do |name, js_code|
          # Handle symbol names that need quoting in JS
          js_name = name.to_s.match?(/^[a-zA-Z_$][a-zA-Z0-9_$]*$/) ? name : "\"#{name}\""
          "  #{js_name}: #{js_code}"
        end.join(",\n")

        <<~JAVASCRIPT
          const kumiRegistry = {
          #{functions_js}
          };
        JAVASCRIPT
      end

      def self.math_functions
        {
          # Basic arithmetic
          add: "(a, b) => a + b",
          subtract: "(a, b) => a - b",
          multiply: "(a, b) => a * b",
          divide: "(a, b) => a / b",
          modulo: "(a, b) => a % b",
          power: "(a, b) => Math.pow(a, b)",

          # Unary operations
          abs: "(a) => Math.abs(a)",
          floor: "(a) => Math.floor(a)",
          ceil: "(a) => Math.ceil(a)",

          # Special operations
          round: "(a, precision = 0) => Number(a.toFixed(precision))",
          clamp: "(value, min, max) => Math.min(max, Math.max(min, value))",

          # Complex mathematical operations
          piecewise_sum: <<~JS.strip
            (value, breaks, rates) => {
              if (breaks.length !== rates.length) {
                throw new Error('breaks & rates size mismatch');
              }
            #{'  '}
              let acc = 0.0;
              let previous = 0.0;
              let marginal = rates[rates.length - 1];
            #{'  '}
              for (let i = 0; i < breaks.length; i++) {
                const upper = breaks[i];
                const rate = rates[i];
            #{'    '}
                if (value <= upper) {
                  marginal = rate;
                  acc += (value - previous) * rate;
                  break;
                } else {
                  acc += (upper - previous) * rate;
                  previous = upper;
                }
              }
            #{'  '}
              return [acc, marginal];
            }
          JS
        }
      end

      def self.comparison_functions
        {
          # Equality operators (using strict equality)
          "==": "(a, b) => a === b",
          "!=": "(a, b) => a !== b",

          # Comparison operators
          ">": "(a, b) => a > b",
          "<": "(a, b) => a < b",
          ">=": "(a, b) => a >= b",
          "<=": "(a, b) => a <= b",

          # Range comparison
          between?: "(value, min, max) => value >= min && value <= max"
        }
      end

      def self.logical_functions
        {
          # Basic logical operations
          and: "(...conditions) => conditions.every(x => x)",
          or: "(...conditions) => conditions.some(x => x)",
          not: "(a) => !a",

          # Collection logical operations
          all?: "(collection) => collection.every(x => x)",
          any?: "(collection) => collection.some(x => x)",
          none?: "(collection) => !collection.some(x => x)"
        }
      end

      def self.string_functions
        {
          # String transformations
          upcase: "(str) => str.toString().toUpperCase()",
          downcase: "(str) => str.toString().toLowerCase()",
          capitalize: "(str) => { const s = str.toString(); return s.charAt(0).toUpperCase() + s.slice(1).toLowerCase(); }",
          strip: "(str) => str.toString().trim()",

          # String queries
          string_length: "(str) => str.toString().length",
          length: "(str) => str.toString().length",

          # String inclusion checks
          string_include?: "(str, substr) => str.toString().includes(substr.toString())",
          includes?: "(str, substr) => str.toString().includes(substr.toString())",
          contains?: "(str, substr) => str.toString().includes(substr.toString())",
          start_with?: "(str, prefix) => str.toString().startsWith(prefix.toString())",
          end_with?: "(str, suffix) => str.toString().endsWith(suffix.toString())",

          # String building
          concat: "(...strings) => strings.map(s => s.toString()).join('')"
        }
      end

      def self.collection_functions
        {
          # Collection queries (reducers)
          empty?: "(collection) => collection.length === 0",
          size: "(collection) => collection.length",

          # Element access
          first: "(collection) => collection[0]",
          last: "(collection) => collection[collection.length - 1]",

          # Mathematical operations on collections
          sum: "(collection) => collection.reduce((a, b) => a + b, 0)",
          min: "(collection) => Math.min(...collection)",
          max: "(collection) => Math.max(...collection)",

          # Collection operations
          include?: "(collection, element) => collection.includes(element)",
          reverse: "(collection) => [...collection].reverse()",
          sort: "(collection) => [...collection].sort()",
          unique: "(collection) => [...new Set(collection)]",
          flatten: "(collection) => collection.flat(Infinity)",

          # Array transformation functions
          map_multiply: "(collection, factor) => collection.map(x => x * factor)",
          map_add: "(collection, value) => collection.map(x => x + value)",
          map_conditional: "(collection, condition_value, true_value, false_value) => collection.map(x => x === condition_value ? true_value : false_value)",

          # Range/index functions
          build_array: "(size) => Array.from({length: size}, (_, i) => i)",
          range: "(start, finish) => Array.from({length: finish - start}, (_, i) => start + i)",

          # Array slicing and grouping
          each_slice: <<~JS.strip,
            (array, size) => {
              const result = [];
              for (let i = 0; i < array.length; i += size) {
                result.push(array.slice(i, i + size));
              }
              return result;
            }
          JS

          join: "(array, separator = '') => array.map(x => x.toString()).join(separator.toString())",

          map_join_rows: "(array_of_arrays, row_separator = '', column_separator = '\\n') => array_of_arrays.map(row => row.join(row_separator.toString())).join(column_separator.toString())",

          # Higher-order collection functions
          map_with_index: "(collection) => collection.map((item, index) => [item, index])",
          indices: "(collection) => Array.from({length: collection.length}, (_, i) => i)"
        }
      end

      def self.conditional_functions
        {
          conditional: "(condition, true_value, false_value) => condition ? true_value : false_value",
          if: "(condition, true_value, false_value = null) => condition ? true_value : false_value",
          coalesce: "(...values) => values.find(v => v != null)"
        }
      end

      def self.type_functions
        {
          # Hash/object operations - assuming TypeFunctions exists
          fetch: "(hash, key, default_value = null) => hash.hasOwnProperty(key) ? hash[key] : default_value",
          has_key?: "(hash, key) => hash.hasOwnProperty(key)",
          keys: "(hash) => Object.keys(hash)",
          values: "(hash) => Object.values(hash)",
          at: "(collection, index) => collection[index]"
        }
      end
    end
  end
end
