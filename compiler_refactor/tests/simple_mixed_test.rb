#!/usr/bin/env ruby

require_relative "../ir_test_helper"

module SimpleMixedTest
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :items do
        float :price
        integer :quantity
      end
      
      float :tax_rate
    end

    # Element-wise operations (should produce arrays)
    value :item_totals, input.items.price * input.items.quantity
    value :doubled_prices, input.items.price * 2.0
    
    # Scalar operations
    value :tax_multiplier, input.tax_rate + 1.0
    
    # Mixed: Element-wise using scalars (array + scalar pattern)  
    value :taxed_totals, item_totals * tax_multiplier
    value :price_plus_tax, doubled_prices + input.tax_rate
    
    # Element-wise with literals
    value :prices_plus_ten, input.items.price + 10.0
    value :quantities_times_five, input.items.quantity * 5
  end
end

puts "=" * 80
puts "SIMPLE MIXED OPERATIONS TEST"
puts "=" * 80

test_data = { 
  items: [
    { price: 25.0, quantity: 2 },
    { price: 40.0, quantity: 3 }
  ],
  tax_rate: 0.08
}

begin
  result = IRTestHelper.compile_schema(SimpleMixedTest, debug: false)
  runner = result[:compiled_schema]
  
  puts "\nTesting mixed operation patterns:\n"
  
  # Element-wise operations
  puts "Element-wise operations:"
  item_totals = runner.bindings[:item_totals].call(test_data)
  doubled_prices = runner.bindings[:doubled_prices].call(test_data)
  puts "  item_totals (price * quantity): #{item_totals.inspect}"
  puts "  doubled_prices (price * 2.0): #{doubled_prices.inspect}"
  
  # Scalar operations  
  puts "\nScalar operations:"
  tax_multiplier = runner.bindings[:tax_multiplier].call(test_data)
  puts "  tax_multiplier (tax_rate + 1.0): #{tax_multiplier.inspect}"
  
  # Mixed operations
  puts "\nMixed operations (array + scalar):"
  taxed_totals = runner.bindings[:taxed_totals].call(test_data)
  price_plus_tax = runner.bindings[:price_plus_tax].call(test_data)
  puts "  taxed_totals (item_totals * tax_multiplier): #{taxed_totals.inspect}"
  puts "  price_plus_tax (doubled_prices + tax_rate): #{price_plus_tax.inspect}"
  
  # Element-wise with literals
  puts "\nElement-wise with literals:"
  prices_plus_ten = runner.bindings[:prices_plus_ten].call(test_data)
  quantities_times_five = runner.bindings[:quantities_times_five].call(test_data)
  puts "  prices_plus_ten: #{prices_plus_ten.inspect}"
  puts "  quantities_times_five: #{quantities_times_five.inspect}"
  
  puts "\n" + "=" * 40
  puts "EXPECTED RESULTS"
  puts "=" * 40
  puts "Items: [(25.0, 2), (40.0, 3)]"
  puts "Tax rate: 0.08"
  puts ""
  puts "Expected:"
  puts "  item_totals: [50.0, 120.0]"
  puts "  doubled_prices: [50.0, 80.0]"
  puts "  tax_multiplier: 1.08"
  puts "  taxed_totals: [54.0, 129.6]"
  puts "  price_plus_tax: [50.08, 80.08]"
  
rescue => e
  puts "Error: #{e.message}"
  puts "  at: #{e.backtrace.first}"
  puts "\nBacktrace:"
  e.backtrace[0..3].each { |line| puts "  #{line}" }
end