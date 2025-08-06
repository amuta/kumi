#!/usr/bin/env ruby

require_relative "tac_test_helper"

module TACTestSchema
  extend Kumi::Schema
  
  schema skip_compiler: true do
    input do
      array :items do
        float :value
        float :weight
      end
      float :multiplier
    end
    
    # Test cases for TAC generation
    value :doubled_values, input.items.value * 2.0
    value :doubled_plus_multiplier, doubled_values + input.multiplier  
    value :inline_chain, (input.items.weight * 2.0) + input.multiplier  # Should generate temp
    value :combined, doubled_values + input.items.weight
  end
end

puts "=== Testing TAC IR System ==="
puts

test_data = {
  items: [
    { value: 10.0, weight: 1.0 },
    { value: 20.0, weight: 2.0 },
    { value: 30.0, weight: 3.0 }
  ],
  multiplier: 5.0
}

begin
  result = TACTestHelper.compile_schema(TACTestSchema, debug: true)
  runner = result[:compiled_schema]
  
  puts "\n=== Results ==="
  expected = {
    doubled_values: [20.0, 40.0, 60.0],
    doubled_plus_multiplier: [25.0, 45.0, 65.0],  
    inline_chain: [7.0, 9.0, 11.0],  # Should be [(1*2)+5, (2*2)+5, (3*2)+5]
    combined: [21.0, 42.0, 63.0]
  }
  
  expected.each do |name, expected_val|
    begin
      actual = runner.bindings[name].call(test_data)
      puts "#{name}: #{actual.inspect} (expected: #{expected_val.inspect})"
      puts "  #{actual == expected_val ? '✓ PASS' : '✗ FAIL'}"
    rescue => e
      puts "#{name}: ERROR - #{e.message}"
    end
  end
  
rescue => e
  puts "Failed: #{e.message}"
  puts "  at: #{e.backtrace.first}"
end