#!/usr/bin/env ruby

require_relative "../ir_test_helper"

module TestCompleteSystem
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :items do
        float :value
        float :weight
      end
      float :multiplier
    end

    # Chain test: declaration -> declaration reference -> inline expression
    value :doubled_values, input.items.value * 2.0
    value :doubled_plus_multiplier, doubled_values + input.multiplier
    value :inline_chain, (input.items.weight * 2.0) + input.multiplier

    # Mixed operations
    value :combined, doubled_values + input.items.weight
  end
end

puts "=== Testing Complete V2 System ==="
puts

# Test data
test_data = {
  items: [
    { value: 10.0, weight: 1.0 },
    { value: 20.0, weight: 2.0 },
    { value: 30.0, weight: 3.0 }
  ],
  multiplier: 5.0
}

puts "Input data:"
puts "  items: #{test_data[:items]}"
puts "  multiplier: #{test_data[:multiplier]}"
puts

begin
  # Compile using our IR system
  result = IRTestHelper.compile_schema(TestCompleteSystem, debug: false)
  runner = result[:compiled_schema]

  puts "=== Results ==="

  # Expected results:
  expected = {
    doubled_values: [20.0, 40.0, 60.0],           # [10*2, 20*2, 30*2]
    doubled_plus_multiplier: [25.0, 45.0, 65.0],  # [20+5, 40+5, 60+5]
    inline_chain: [7.0, 9.0, 11.0],               # [(1*2)+5, (2*2)+5, (3*2)+5]
    combined: [21.0, 42.0, 63.0]                  # [20+1, 40+2, 60+3]
  }

  %i[doubled_values doubled_plus_multiplier inline_chain combined].each do |name|
    actual = runner.bindings[name].call(test_data)
    expected_val = expected[name]

    puts "#{name}:"
    puts "  actual:   #{actual.inspect}"
    puts "  expected: #{expected_val.inspect}"

    if actual == expected_val
      puts "  ✓ PASS"
    else
      puts "  ✗ FAIL"
    end
    puts
  rescue StandardError => e
    puts "#{name}: ERROR - #{e.message}"
    puts "  at: #{e.backtrace.first}"
    puts
  end
rescue StandardError => e
  puts "Compilation failed: #{e.message}"
  puts "  at: #{e.backtrace.first}"
end
