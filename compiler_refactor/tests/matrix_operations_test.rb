#!/usr/bin/env ruby

require_relative "../ir_test_helper"

module MatrixOps
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :matrix do
        element :array, :rows do
          element :integer, :cell
        end
      end
    end

    # Basic matrix properties
    value :matrix_height, fn(:size, input.matrix)
    value :row_widths, fn(:size, input.matrix.rows)

    # Cell-level operations
    value :all_cells, fn(:flatten, input.matrix.rows.cell)
    value :total_cells, fn(:size, all_cells)
    value :cell_sum, fn(:sum, all_cells)
    value :max_cell, fn(:max, all_cells)

    # Element-wise operations on cells
    value :doubled_cells, input.matrix.rows.cell * 2
    value :cells_plus_index, input.matrix.rows.cell + 1

    # Traits on matrix elements
    trait :has_large_cells, input.matrix.rows.cell > 5
    trait :has_even_cells, input.matrix.rows.cell.even?

    # Cascades with matrix data
    value :cell_categories do
      on has_large_cells, "large"
      base "small"
    end

    # Mixed operations
    value :processed_matrix, [matrix_height, total_cells, cell_sum]
    value :stats_summary do
      on has_large_cells, [max_cell, "high"]
      base [cell_sum, "low"]
    end
  end
end

def test_matrix_operations
  puts "=== Matrix Operations Test ==="

  # Test data: 3x3-ish irregular matrix
  test_data = {
    matrix: [
      [1, 2, 3],      # Row 0: 3 cells
      [4, 5],         # Row 1: 2 cells
      [6, 7, 8, 9]    # Row 2: 4 cells
    ]
  }

  puts "Input matrix:"
  test_data[:matrix].each_with_index do |row, i|
    puts "  Row #{i}: #{row.inspect}"
  end
  puts

  begin
    result = IRTestHelper.compile_schema(MatrixOps, debug: false)
    runner = result[:compiled_schema]

    # Let's examine the detector metadata for our failing operations
    analysis = result[:analysis]
    detector_metadata = analysis.state[:detector_metadata] if analysis

    if detector_metadata
      puts "doubled_cells metadata: #{detector_metadata[:doubled_cells]}"
      puts "cells_plus_index metadata: #{detector_metadata[:cells_plus_index]}"
    else
      puts "No detector metadata available"
    end
    puts

    # Test all values
    values_to_test = %i[
      matrix_height
      row_widths
      all_cells
      total_cells
      cell_sum
      max_cell
      doubled_cells
      cells_plus_index
      cell_categories
      processed_matrix
      stats_summary
    ]

    puts "Results:"
    values_to_test.each do |name|
      value = runner.bindings[name].call(test_data)
      puts "  #{name}: #{value.inspect}"
    rescue StandardError => e
      puts "  #{name}: ERROR - #{e.message}"
    end

    # Test traits separately
    puts "\nTraits:"
    %i[has_large_cells has_even_cells].each do |trait|
      value = runner.bindings[trait].call(test_data)
      puts "  #{trait}: #{value.inspect}"
    rescue StandardError => e
      puts "  #{trait}: ERROR - #{e.message}"
    end
  rescue StandardError => e
    puts "Compilation failed: #{e.message}"
    puts "  at: #{e.backtrace.first}"
  end
end

test_matrix_operations
