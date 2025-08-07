#!/usr/bin/env ruby

require_relative "../ir_test_helper"

module SimpleNestingTest
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :items do
        float :price
        integer :quantity
      end
    end

    # Level 1: Basic element-wise operations
    value :doubled_prices, input.items.price * 2.0
    value :tripled_quantities, input.items.quantity * 3.0
    
    # Level 2: Operations on declarations (array + scalar)
    value :doubled_plus_five, doubled_prices + 5.0
    value :tripled_minus_one, tripled_quantities - 1.0
    
    # Level 3: Chain of declaration references
    value :chain_step1, doubled_plus_five * 1.1
    value :chain_step2, chain_step1 + 10.0
    value :chain_step3, chain_step2 / 2.0
    
    # Level 4: Multiple separate chains
    value :prices_chain, doubled_prices * 0.9
    value :final_prices, prices_chain + 0.5
    
    value :quantities_chain, tripled_quantities + 2.0  
    value :final_quantities, quantities_chain * 1.2
  end
end

puts "=" * 80
puts "SIMPLE NESTING AND CHAINING TEST"
puts "=" * 80

test_data = { 
  items: [
    { price: 10.0, quantity: 2 },
    { price: 20.0, quantity: 3 }
  ]
}

begin
  result = IRTestHelper.compile_schema(SimpleNestingTest, debug: false)
  runner = result[:compiled_schema]
  
  puts "\nTesting declaration chaining:\n"
  
  # Level 1: Basic element-wise
  puts "Level 1 - Basic element-wise operations:"
  doubled_prices = runner.bindings[:doubled_prices].call(test_data)
  tripled_quantities = runner.bindings[:tripled_quantities].call(test_data)
  puts "  doubled_prices (price * 2.0): #{doubled_prices.inspect}"
  puts "  tripled_quantities (quantity * 3.0): #{tripled_quantities.inspect}"
  
  # Level 2: Operations on declarations
  puts "\nLevel 2 - Operations on declarations:"
  doubled_plus_five = runner.bindings[:doubled_plus_five].call(test_data)
  tripled_minus_one = runner.bindings[:tripled_minus_one].call(test_data)
  puts "  doubled_plus_five: #{doubled_plus_five.inspect}"
  puts "  tripled_minus_one: #{tripled_minus_one.inspect}"
  
  # Level 3: Chain of declarations
  puts "\nLevel 3 - Chain of declarations:"
  chain_step1 = runner.bindings[:chain_step1].call(test_data)
  chain_step2 = runner.bindings[:chain_step2].call(test_data)
  chain_step3 = runner.bindings[:chain_step3].call(test_data)
  puts "  chain_step1 (doubled_plus_five * 1.1): #{chain_step1.inspect}"
  puts "  chain_step2 (chain_step1 + 10.0): #{chain_step2.inspect}"
  puts "  chain_step3 (chain_step2 / 2.0): #{chain_step3.inspect}"
  
  # Level 4: Multiple chains
  puts "\nLevel 4 - Multiple parallel chains:"
  prices_chain = runner.bindings[:prices_chain].call(test_data)
  final_prices = runner.bindings[:final_prices].call(test_data)
  quantities_chain = runner.bindings[:quantities_chain].call(test_data)
  final_quantities = runner.bindings[:final_quantities].call(test_data)
  puts "  prices_chain: #{prices_chain.inspect}"
  puts "  final_prices: #{final_prices.inspect}"
  puts "  quantities_chain: #{quantities_chain.inspect}"
  puts "  final_quantities: #{final_quantities.inspect}"
  
  puts "\n" + "=" * 40
  puts "MANUAL VERIFICATION"
  puts "=" * 40
  puts "Item 1: price=10.0, quantity=2"
  puts "Item 2: price=20.0, quantity=3"
  puts ""
  puts "Expected chain for prices:"
  puts "  doubled_prices: [20.0, 40.0]"
  puts "  doubled_plus_five: [25.0, 45.0]"
  puts "  chain_step1: [27.5, 49.5]"
  puts "  chain_step2: [37.5, 59.5]"
  puts "  chain_step3: [18.75, 29.75]"
  
rescue => e
  puts "Error: #{e.message}"
  puts "  at: #{e.backtrace.first}"
  puts "\nBacktrace:"
  e.backtrace[0..3].each { |line| puts "  #{line}" }
end