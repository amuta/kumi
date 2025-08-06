#!/usr/bin/env ruby

require_relative "../ir_test_helper"

puts "=== Finding the nested_call source ==="

# Try to reproduce the exact pattern that triggered nested_call
module NestedCallDebug
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :matrix do
        element :array, :rows do
          element :integer, :cell
        end
      end
    end

    # Start simple
    value :doubled_cells, input.matrix.rows.cell * 2

    # This might be what triggers nested_call - using a vectorized result in cascade?
    value :cell_categories do
      on doubled_cells > 5, "large" # Using vectorized result in condition
      base "small"
    end
  end
end

begin
  result = IRTestHelper.compile_schema(NestedCallDebug, debug: false)
  puts "✓ Pattern works"
rescue StandardError => e
  puts "✗ Pattern failed: #{e.message}"
  puts "    Location: #{e.backtrace.first}"

  # Show more details about the error
  puts "\n=== This is the nested_call pattern we need to handle! ===" if e.message.include?("nested_call")
end
