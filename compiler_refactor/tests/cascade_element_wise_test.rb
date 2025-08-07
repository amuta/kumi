#!/usr/bin/env ruby

require_relative "../ir_test_helper"

module CascadeElementWiseTest
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :items do
        float :price
        string :category
        integer :quantity
      end
      
      float :discount_threshold
    end

    # Basic element-wise operations for cascade conditions
    value :doubled_prices, input.items.price * 2.0
    value :total_values, input.items.price * input.items.quantity

    # Traits using element-wise operations
    trait :expensive_items, (input.items.price > 50.0)
    trait :high_quantity, (input.items.quantity > 2)
    trait :premium_category, (input.items.category == "premium")
    
    # Cascades with element-wise conditions and results
    value :discount_rates do
      on expensive_items, fn(:multiply, doubled_prices, 0.1)  # 10% of doubled price as discount
      on high_quantity, fn(:multiply, total_values, 0.05)     # 5% of total value as discount
      base 5.0  # Flat $5 discount
    end
    
    value :final_prices do
      on premium_category, fn(:subtract, doubled_prices, discount_rates)
      on expensive_items, fn(:subtract, input.items.price, fn(:multiply, discount_rates, 0.5))
      base fn(:subtract, input.items.price, 1.0)  # Basic $1 discount
    end
    
    # Simpler cascade for testing
    value :bonus_points do
      on expensive_items, fn(:multiply, total_values, 0.1)
      base fn(:multiply, doubled_prices, 0.05)
    end
  end
end

puts "=" * 80
puts "CASCADE WITH ELEMENT-WISE OPERATIONS TEST"  
puts "=" * 80

test_data = { 
  items: [
    { price: 60.0, category: "premium", quantity: 1 },    # expensive, premium, low qty
    { price: 30.0, category: "standard", quantity: 4 },   # cheap, standard, high qty  
    { price: 80.0, category: "standard", quantity: 2 }    # expensive, standard, med qty
  ],
  discount_threshold: 15.0
}

begin
  result = IRTestHelper.compile_schema(CascadeElementWiseTest, debug: false)
  runner = result[:compiled_schema]
  
  puts "\nTesting element-wise operations in cascades:\n"
  
  # Basic element-wise operations
  puts "Basic element-wise operations:"
  doubled_prices = runner.bindings[:doubled_prices].call(test_data)
  total_values = runner.bindings[:total_values].call(test_data)
  puts "  doubled_prices: #{doubled_prices.inspect}"
  puts "  total_values: #{total_values.inspect}"
  
  # Traits (boolean arrays)
  puts "\nTraits (boolean conditions):"
  expensive_items = runner.bindings[:expensive_items].call(test_data)
  high_quantity = runner.bindings[:high_quantity].call(test_data)
  premium_category = runner.bindings[:premium_category].call(test_data)
  puts "  expensive_items (price > 50): #{expensive_items.inspect}"
  puts "  high_quantity (quantity > 2): #{high_quantity.inspect}"
  puts "  premium_category (category == premium): #{premium_category.inspect}"
  
  # Cascades with element-wise results
  puts "\nCascades with element-wise results:"
  discount_rates = runner.bindings[:discount_rates].call(test_data)
  final_prices = runner.bindings[:final_prices].call(test_data)
  bonus_points = runner.bindings[:bonus_points].call(test_data)
  puts "  discount_rates: #{discount_rates.inspect}"
  puts "  final_prices: #{final_prices.inspect}"
  puts "  bonus_points: #{bonus_points.inspect}"
  
  puts "\n" + "=" * 50
  puts "MANUAL VERIFICATION"
  puts "=" * 50
  puts "Item 1: price=60.0, premium, qty=1"
  puts "  expensive_items: true (60 > 50)"
  puts "  high_quantity: false (1 <= 2)"  
  puts "  premium_category: true"
  puts "  doubled_price: 120.0"
  puts "  total_value: 60.0"
  puts ""
  puts "Item 2: price=30.0, standard, qty=4"
  puts "  expensive_items: false (30 <= 50)"
  puts "  high_quantity: true (4 > 2)"
  puts "  premium_category: false"
  puts "  doubled_price: 60.0"
  puts "  total_value: 120.0"
  puts ""
  puts "Item 3: price=80.0, standard, qty=2"
  puts "  expensive_items: true (80 > 50)"
  puts "  high_quantity: false (2 <= 2)"
  puts "  premium_category: false"
  puts "  doubled_price: 160.0"
  puts "  total_value: 160.0"
  puts ""
  puts "Expected discount_rates:"
  puts "  Item 1: expensive_items=true → doubled_prices * 0.1 = 12.0"
  puts "  Item 2: high_quantity=true → total_values * 0.05 = 6.0"
  puts "  Item 3: expensive_items=true → doubled_prices * 0.1 = 16.0"
  puts "  Expected: [12.0, 6.0, 16.0]"
  
rescue => e
  puts "Error: #{e.message}"
  puts "  at: #{e.backtrace.first}"
  puts "\nBacktrace:"
  e.backtrace[0..5].each { |line| puts "  #{line}" }
end