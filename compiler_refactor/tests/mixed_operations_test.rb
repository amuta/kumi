#!/usr/bin/env ruby

require_relative "../ir_test_helper"

module MixedOperationsTest
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :items do
        float :price
        integer :quantity
      end
      
      float :tax_rate
      integer :bonus_threshold
    end

    # Element-wise operations (arrays)
    value :item_totals, input.items.price * input.items.quantity
    value :discounted_prices, input.items.price * 0.9
    
    # Scalar operations
    value :tax_multiplier, input.tax_rate + 1.0
    value :adjusted_threshold, input.bonus_threshold * 2
    
    # Mixed: Array operations using scalar inputs
    value :taxed_totals, item_totals * tax_multiplier
    value :price_vs_threshold, input.items.price - input.bonus_threshold
    
    # Mixed: Scalar operations using array results (reductions)
    value :total_sum, fn(:sum, item_totals)
    value :max_price, fn(:max, input.items.price) 
    value :min_total, fn(:min, taxed_totals)
    
    # Combinations of all types
    value :complex_calc1, total_sum * tax_multiplier
    value :complex_calc2, max_price + adjusted_threshold
    value :threshold_vs_max, fn(:subtract, input.bonus_threshold, max_price)
  end
end

puts "=" * 80
puts "MIXED SCALAR AND ARRAY OPERATIONS TEST"
puts "=" * 80

test_data = { 
  items: [
    { price: 25.0, quantity: 2 },   # total: 50.0
    { price: 40.0, quantity: 3 },   # total: 120.0
    { price: 15.0, quantity: 1 }    # total: 15.0
  ],
  tax_rate: 0.08,        # tax_multiplier: 1.08
  bonus_threshold: 30    # adjusted_threshold: 60
}

begin
  result = IRTestHelper.compile_schema(MixedOperationsTest, debug: false)
  runner = result[:compiled_schema]
  
  puts "\nTesting mixed operation types:\n"
  
  # Element-wise operations (arrays)
  puts "Element-wise operations (arrays):"
  item_totals = runner.bindings[:item_totals].call(test_data)
  discounted_prices = runner.bindings[:discounted_prices].call(test_data)
  puts "  item_totals (price * quantity): #{item_totals.inspect}"
  puts "  discounted_prices (price * 0.9): #{discounted_prices.inspect}"
  
  # Scalar operations
  puts "\nScalar operations:"
  tax_multiplier = runner.bindings[:tax_multiplier].call(test_data)
  adjusted_threshold = runner.bindings[:adjusted_threshold].call(test_data)
  puts "  tax_multiplier (tax_rate + 1.0): #{tax_multiplier.inspect}"
  puts "  adjusted_threshold (threshold * 2): #{adjusted_threshold.inspect}"
  
  # Mixed: Array operations using scalars
  puts "\nMixed: Array operations using scalars:"
  taxed_totals = runner.bindings[:taxed_totals].call(test_data)
  price_vs_threshold = runner.bindings[:price_vs_threshold].call(test_data)
  puts "  taxed_totals (item_totals * tax_multiplier): #{taxed_totals.inspect}"
  puts "  price_vs_threshold (price - threshold): #{price_vs_threshold.inspect}"
  
  # Reductions: Array → Scalar
  puts "\nReductions: Array → Scalar:"
  total_sum = runner.bindings[:total_sum].call(test_data)
  max_price = runner.bindings[:max_price].call(test_data)
  min_total = runner.bindings[:min_total].call(test_data)
  puts "  total_sum: #{total_sum.inspect}"
  puts "  max_price: #{max_price.inspect}"
  puts "  min_total: #{min_total.inspect}"
  
  # Complex combinations
  puts "\nComplex combinations:"
  complex_calc1 = runner.bindings[:complex_calc1].call(test_data)
  complex_calc2 = runner.bindings[:complex_calc2].call(test_data)
  threshold_vs_max = runner.bindings[:threshold_vs_max].call(test_data)
  puts "  complex_calc1 (total_sum * tax_multiplier): #{complex_calc1.inspect}"
  puts "  complex_calc2 (max_price + adjusted_threshold): #{complex_calc2.inspect}"
  puts "  threshold_vs_max (threshold - max_price): #{threshold_vs_max.inspect}"
  
  puts "\n" + "=" * 50
  puts "MANUAL VERIFICATION"
  puts "=" * 50
  puts "Items: [(25.0, 2), (40.0, 3), (15.0, 1)]"
  puts "Tax rate: 0.08, Bonus threshold: 30"
  puts ""
  puts "Expected calculations:"
  puts "  item_totals: [50.0, 120.0, 15.0]"
  puts "  discounted_prices: [22.5, 36.0, 13.5]"
  puts "  tax_multiplier: 1.08"
  puts "  taxed_totals: [54.0, 129.6, 16.2]"
  puts "  total_sum: 185.0"
  puts "  max_price: 40.0"
  puts "  complex_calc1: 185.0 * 1.08 = 199.8"
  puts "  complex_calc2: 40.0 + 60 = 100.0"
  
rescue => e
  puts "Error: #{e.message}"
  puts "  at: #{e.backtrace.first}"
  puts "\nBacktrace:"
  e.backtrace[0..5].each { |line| puts "  #{line}" }
end