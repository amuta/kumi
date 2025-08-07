#!/usr/bin/env ruby

require_relative "tac_test_helper"

module SimpleTACDebug
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :items do
        float :value
      end
      float :multiplier
    end

    # Super simple case that should work
    value :simple_multiply, input.items.value * 2.0
    # Complex case that needs TAC  
    value :complex_nested, (input.items.value * 2.0) + input.multiplier
  end
end

puts "=" * 60
puts "SIMPLE TAC DEBUG - STEP BY STEP"
puts "=" * 60

test_data = {
  items: [
    { value: 10.0 },
    { value: 20.0 }
  ],
  multiplier: 5.0
}

puts "\nTest data:"
puts "  items: #{test_data[:items]}"
puts "  multiplier: #{test_data[:multiplier]}"

begin
  result = TACTestHelper.compile_schema(SimpleTACDebug, debug: true)
  
  puts "\n" + "=" * 40
  puts "ACCESSOR INSPECTION"
  puts "=" * 40
  
  # Test each accessor individually
  accessor_tests = [
    "items.value:element",
    "multiplier:structure"
  ]
  
  accessor_tests.each do |accessor_name|
    if result[:tac_ir][:accessors][accessor_name]
      puts "\nTesting #{accessor_name}:"
      accessor_result = result[:tac_ir][:accessors][accessor_name].call(test_data)
      puts "  Result: #{accessor_result.inspect}"
      puts "  Type: #{accessor_result.class}"
      puts "  Is Array: #{accessor_result.is_a?(Array)}"
    else
      puts "\n#{accessor_name}: NOT FOUND"
    end
  end
  
  puts "\n" + "=" * 40
  puts "BINDING EXECUTION TEST"
  puts "=" * 40
  
  compiled_schema = result[:compiled_schema]
  
  # Test simple case first
  puts "\nTesting simple_multiply:"
  if compiled_schema.bindings[:simple_multiply]
    begin
      simple_result = compiled_schema.bindings[:simple_multiply].call(test_data)
      puts "  Result: #{simple_result.inspect}"
      puts "  Expected: [20.0, 40.0]"
    rescue => e
      puts "  ERROR: #{e.message}"
      puts "  Location: #{e.backtrace.first}"
    end
  else
    puts "  No binding found"
  end
  
  # Test temp binding
  puts "\nTesting __temp_1 (if exists):"
  if compiled_schema.bindings[:__temp_1]
    begin
      temp_result = compiled_schema.bindings[:__temp_1].call(test_data)
      puts "  Result: #{temp_result.inspect}"
      puts "  Expected: [20.0, 40.0]"
    rescue => e
      puts "  ERROR: #{e.message}"
      puts "  Location: #{e.backtrace.first}"
    end
  else
    puts "  No __temp_1 binding found"
  end
  
  # Test complex case
  puts "\nTesting complex_nested:"
  if compiled_schema.bindings[:complex_nested]
    begin
      complex_result = compiled_schema.bindings[:complex_nested].call(test_data)
      puts "  Result: #{complex_result.inspect}"
      puts "  Expected: [25.0, 45.0]"  # (10*2)+5, (20*2)+5
    rescue => e
      puts "  ERROR: #{e.message}"
      puts "  Location: #{e.backtrace.first}"
    end
  else
    puts "  No binding found"
  end
  
rescue => e
  puts "Failed: #{e.message}"
  puts "  at: #{e.backtrace.first}"
end