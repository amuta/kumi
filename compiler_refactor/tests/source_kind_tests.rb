#!/usr/bin/env ruby

require_relative "../ir_test_helper"

puts "=== Testing Different Source Kinds ==="

# Test 1: input_field (basic array input)
puts "\n--- Test 1: input_field ---"
module InputFieldTest
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :numbers, elem: { type: :integer }
    end

    value :array_size, fn(:size, input.numbers)
  end
end

begin
  IRTestHelper.compile_schema(InputFieldTest, debug: false)
  puts "✓ input_field works"
rescue StandardError => e
  puts "✗ input_field failed: #{e.message}"
end

# Test 2: input_element (nested element access)
puts "\n--- Test 2: input_element ---"
module InputElementTest
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :matrix do
        element :array, :rows do
          element :integer, :cell
        end
      end
    end

    value :all_cells, fn(:flatten, input.matrix.rows.cell)
  end
end

begin
  IRTestHelper.compile_schema(InputElementTest, debug: false)
  puts "✓ input_element works"
rescue StandardError => e
  puts "✗ input_element failed: #{e.message}"
end

# Test 3: declaration (using computed values)
puts "\n--- Test 3: declaration ---"
module DeclarationTest
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :numbers, elem: { type: :integer }
    end

    value :doubled, input.numbers * 2
    value :doubled_sum, fn(:sum, doubled)
  end
end

begin
  IRTestHelper.compile_schema(DeclarationTest, debug: false)
  puts "✓ declaration works"
rescue StandardError => e
  puts "✗ declaration failed: #{e.message}"
end

# Test 4: What triggers nested_call?
puts "\n--- Test 4: nested_call trigger? ---"
module NestedCallTest
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :matrix do
        element :array, :rows do
          element :integer, :cell
        end
      end
    end

    # This should trigger the nested_call based on the error we saw
    value :doubled_cells, input.matrix.rows.cell * 2
    value :doubled_plus_one, doubled_cells + 1 # Using vectorized result in another operation
  end
end

begin
  IRTestHelper.compile_schema(NestedCallTest, debug: false)
  puts "✓ nested_call works"
rescue StandardError => e
  puts "✗ nested_call failed: #{e.message}"
  puts "    Error details: #{e.backtrace.first}"
end
