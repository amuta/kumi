#!/usr/bin/env ruby

require_relative "../ir_test_helper"

module ArrayLiterals
  extend Kumi::Schema

  # Constants defined outside schema
  NUMBERS = [1, 2, 3, 4, 5].freeze
  FLOATS = [1.5, 2.5, 3.5].freeze

  schema skip_compiler: true do
    input do
      integer :index
      string :category
    end

    # Inline array literals
    value :inline_array, [10, 20, 30]

    # Array from constant
    value :const_array, NUMBERS

    # Conditional arrays
    trait :is_premium, input.category == "premium"

    value :tier_values do
      on is_premium, [100, 200, 300]
      base [10, 20, 30]
    end

    # Mixed literals in arrays
    value :mixed_array, [1, 2.5, "hello", true]

    # Arrays with expressions inside
    value :computed_array, [input.index, input.index * 2, input.index + 10]

    # Mix of literals and references
    value :base_value, 100
    value :mixed_refs, [base_value, input.index, 42]

    # Nested arrays
    value :matrix, [[1, 2], [3, 4], [5, 6]]

    # Using constants in cascades
    value :float_selection do
      on is_premium, FLOATS
      base [0.5, 1.0, 1.5]
    end
  end
end

# First, let's see what the AST looks like
puts "=== Examining Array Expressions in AST ==="
ast = ArrayLiterals.__syntax_tree__

# Find the inline_array value
inline_array_decl = ast.attributes.find { |a| a.name == :inline_array }
if inline_array_decl
  puts "inline_array expression class: #{inline_array_decl.expression.class}"
  puts "inline_array expression: #{inline_array_decl.expression.inspect}"
  puts "Elements: #{inline_array_decl.expression.elements.map(&:inspect)}" if inline_array_decl.expression.respond_to?(:elements)
end

puts "\n=== Attempting Compilation ==="
begin
  result = IRTestHelper.compile_schema(ArrayLiterals, debug: true)
  puts "✓ Compilation successful!"

  puts "\n=== Testing Execution ==="

  # Test basic case
  test_data = { index: 5, category: "basic" }
  runner = result[:compiled_schema]

  puts "Test input: #{test_data}"
  puts

  # Test all array values
  values_to_test = %i[
    inline_array
    const_array
    tier_values
    mixed_array
    computed_array
    mixed_refs
    matrix
    float_selection
  ]

  values_to_test.each do |value_name|
    result_value = runner.bindings[value_name].call(test_data)
    puts "#{value_name}: #{result_value.inspect}"
  rescue StandardError => e
    puts "#{value_name}: ERROR - #{e.message}"
  end

  puts "\n=== Testing Premium Category ==="
  premium_data = { index: 7, category: "premium" }
  puts "Test input: #{premium_data}"
  puts

  %i[tier_values float_selection].each do |value_name|
    result_value = runner.bindings[value_name].call(premium_data)
    puts "#{value_name}: #{result_value.inspect}"
  rescue StandardError => e
    puts "#{value_name}: ERROR - #{e.message}"
  end
rescue StandardError => e
  puts "✗ Compilation failed: #{e.message}"
  puts "  at: #{e.backtrace.first}"
end
