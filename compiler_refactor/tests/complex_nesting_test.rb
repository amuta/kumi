#!/usr/bin/env ruby

require_relative "../ir_test_helper"

module ComplexNestingTest
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :items do
        float :price
        integer :quantity
        float :discount_rate
      end
      
      float :tax_rate
    end

    # Level 1: Basic element-wise operations
    value :subtotals, input.items.price * input.items.quantity
    value :discounted_prices, input.items.price * (1.0 - input.items.discount_rate)
    
    # Level 2: Operations on declarations
    value :discounted_subtotals, discounted_prices * input.items.quantity
    value :subtotals_plus_ten, subtotals + 10.0
    
    # Level 3: Multiple declaration references
    value :price_difference, subtotals - discounted_subtotals
    value :adjusted_totals, subtotals_plus_ten * 1.1
    
    # Level 4: Complex chained operations (requires TAC)
    value :complex_calculation, (subtotals + discounted_subtotals) * input.tax_rate
    value :super_complex, ((subtotals * 1.1) + (discounted_subtotals * 0.9)) / 2.0
  end
end

puts "=" * 80
puts "COMPLEX NESTING AND REFERENCING TEST"
puts "=" * 80

test_data = { 
  items: [
    { price: 100.0, quantity: 2, discount_rate: 0.1 },
    { price: 50.0, quantity: 3, discount_rate: 0.2 }
  ],
  tax_rate: 0.08
}

begin
  result = IRTestHelper.compile_schema(ComplexNestingTest, debug: false)
  runner = result[:compiled_schema]
  
  puts "\nTesting all levels of complexity:\n"
  
  # Level 1: Basic element-wise
  puts "Level 1 - Basic element-wise operations:"
  subtotals = runner.bindings[:subtotals].call(test_data)
  discounted_prices = runner.bindings[:discounted_prices].call(test_data)
  puts "  subtotals (price * quantity): #{subtotals.inspect}"
  puts "  discounted_prices: #{discounted_prices.inspect}"
  
  # Level 2: Operations on declarations
  puts "\nLevel 2 - Operations on declarations:"
  discounted_subtotals = runner.bindings[:discounted_subtotals].call(test_data)
  subtotals_plus_ten = runner.bindings[:subtotals_plus_ten].call(test_data)
  puts "  discounted_subtotals: #{discounted_subtotals.inspect}"
  puts "  subtotals_plus_ten: #{subtotals_plus_ten.inspect}"
  
  # Level 3: Multiple declaration references
  puts "\nLevel 3 - Multiple declaration references:"
  price_difference = runner.bindings[:price_difference].call(test_data)
  adjusted_totals = runner.bindings[:adjusted_totals].call(test_data)
  puts "  price_difference (subtotals - discounted_subtotals): #{price_difference.inspect}"
  puts "  adjusted_totals: #{adjusted_totals.inspect}"
  
  # Level 4: Complex expressions (should use TAC)
  puts "\nLevel 4 - Complex expressions (TAC system):"
  begin
    complex_calculation = runner.bindings[:complex_calculation].call(test_data)
    puts "  complex_calculation: #{complex_calculation.inspect}"
  rescue => e
    puts "  complex_calculation: Uses TAC - #{e.message}"
  end
  
  begin
    super_complex = runner.bindings[:super_complex].call(test_data)
    puts "  super_complex: #{super_complex.inspect}"
  rescue => e
    puts "  super_complex: Uses TAC - #{e.message}"
  end
  
  puts "\n" + "=" * 40
  puts "EXPECTED CALCULATIONS"
  puts "=" * 40
  puts "Item 1: price=100, qty=2, discount=0.1"
  puts "  subtotal: 100 * 2 = 200"
  puts "  discounted_price: 100 * (1-0.1) = 90"
  puts "  discounted_subtotal: 90 * 2 = 180"
  puts ""
  puts "Item 2: price=50, qty=3, discount=0.2"  
  puts "  subtotal: 50 * 3 = 150"
  puts "  discounted_price: 50 * (1-0.2) = 40"
  puts "  discounted_subtotal: 40 * 3 = 120"
  puts ""
  puts "Expected results:"
  puts "  subtotals: [200.0, 150.0]"
  puts "  discounted_prices: [90.0, 40.0]"
  puts "  discounted_subtotals: [180.0, 120.0]"
  puts "  price_difference: [20.0, 30.0]"
  
rescue => e
  puts "Error: #{e.message}"
  puts "  at: #{e.backtrace.first}"
  puts "\nBacktrace:"
  e.backtrace[0..5].each { |line| puts "  #{line}" }
end