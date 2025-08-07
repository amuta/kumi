#!/usr/bin/env ruby

require_relative "../ir_test_helper"

module CascadeFactoryDebug
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :items do
        float :price
      end
    end

    trait :expensive_items, (input.items.price > 50.0)
    
    value :discount_rates do
      on expensive_items, 12.0
      base 5.0
    end
  end
end

puts "=" * 60
puts "CASCADE FACTORY DEBUG"
puts "=" * 60

test_data = { items: [{ price: 60.0 }, { price: 30.0 }] }

begin
  result = IRTestHelper.compile_schema(CascadeFactoryDebug, debug: false)
  
  puts "\nDetailed IR inspection:"
  discount_instruction = result[:ir][:instructions].find { |i| i[:name] == :discount_rates }
  compilation = discount_instruction[:compilation]
  
  puts "  Operation type: #{discount_instruction[:operation_type]}"
  puts "  Compilation type: #{compilation[:type]}"
  puts "  Cases count: #{compilation[:cases].size}"
  
  # Check if this should be element-wise
  analysis = IRTestHelper.get_analysis(CascadeFactoryDebug)
  detector_metadata = analysis.state[:detector_metadata]
  cascade_meta = detector_metadata[:discount_rates]
  puts "  BroadcastDetector says:"
  puts "    operation_type: #{cascade_meta[:operation_type]}"
  puts "    _detected_element_wise: #{cascade_meta[:_detected_element_wise]}"
  
  compilation[:cases].each_with_index do |c, i|
    puts "    Case #{i}:"
    puts "      condition: #{c[:condition].inspect}"
    puts "      result: #{c[:result].inspect}"
  end
  
  puts "\nTesting factory components manually:"
  
  # Test individual components
  expensive_items = result[:compiled_schema].bindings[:expensive_items].call(test_data)
  puts "  expensive_items: #{expensive_items.inspect}"
  
  puts "\nTesting cascade factory logic step by step:"
  
  # Simulate what the factory should do
  puts "  For element 0 (price=60.0):"
  puts "    expensive_items[0] = #{expensive_items[0]} → should match first condition"
  puts "    Expected result: 12.0"
  
  puts "  For element 1 (price=30.0):"
  puts "    expensive_items[1] = #{expensive_items[1]} → should NOT match first condition"
  puts "    Should fall through to base case (condition=true, result=5.0)"
  puts "    Expected result: 5.0"
  
  puts "\nActual cascade result:"
  discount_rates = result[:compiled_schema].bindings[:discount_rates].call(test_data)
  puts "  discount_rates: #{discount_rates.inspect}"
  puts "  Expected: [12.0, 5.0]"

rescue => e
  puts "Error: #{e.message}"
  puts "Backtrace: #{e.backtrace[0..2]}"
end