#!/usr/bin/env ruby

require_relative "../ir_test_helper"

module CascadeDebugSimple
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :items do
        float :price
      end
    end

    # Simple element-wise for reference
    value :doubled_prices, input.items.price * 2.0
    
    # Trait for cascade condition
    trait :expensive_items, (input.items.price > 50.0)
    
    # Simple cascade
    value :discount_rates do
      on expensive_items, 12.0  # Use literal instead of expression for debugging
      base 5.0
    end
  end
end

puts "=" * 60
puts "SIMPLE CASCADE DEBUG"
puts "=" * 60

test_data = { items: [{ price: 60.0 }, { price: 30.0 }] }

begin
  result = IRTestHelper.compile_schema(CascadeDebugSimple, debug: false)
  runner = result[:compiled_schema]
  
  puts "\nStep-by-step evaluation:"
  
  puts "\n1. Basic values:"
  doubled_prices = runner.bindings[:doubled_prices].call(test_data)
  expensive_items = runner.bindings[:expensive_items].call(test_data)
  puts "  doubled_prices: #{doubled_prices.inspect}"
  puts "  expensive_items: #{expensive_items.inspect}"
  
  puts "\n2. Manual cascade logic check:"
  puts "  For item 0 (price=60.0): expensive_items[0]=#{expensive_items[0]} → should get 12.0"
  puts "  For item 1 (price=30.0): expensive_items[1]=#{expensive_items[1]} → should get 5.0 (base)"
  puts "  Expected result: [12.0, 5.0]"
  
  puts "\n3. Actual cascade execution:"
  discount_rates = runner.bindings[:discount_rates].call(test_data)
  puts "  discount_rates: #{discount_rates.inspect}"
  
  if discount_rates.nil?
    puts "\n4. ERROR: Cascade returned nil - debugging cascade lambda..."
    
    # Let's try to debug what's happening inside
    cascade_lambda = runner.bindings[:discount_rates]
    puts "  cascade_lambda class: #{cascade_lambda.class}"
    
    begin
      # Try calling with debug
      puts "  Attempting manual execution..."
      result_debug = cascade_lambda.call(test_data)
      puts "  Manual execution result: #{result_debug.inspect}"
    rescue => e
      puts "  Manual execution failed: #{e.message}"
      puts "  Backtrace: #{e.backtrace.first(3)}"
    end
  end

rescue => e
  puts "Error: #{e.message}"
  puts "  at: #{e.backtrace.first}"
end