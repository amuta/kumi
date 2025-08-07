#!/usr/bin/env ruby

require_relative "../ir_test_helper"

module ComplexRankedBroadcastCascade
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      float :base_multiplier     # scalar
      float :discount_rate       # scalar
      array :items do
        float :price
        integer :quantity
        float :tax_rate          # per-item tax rate (same array context)
        string :category         # just a string field
      end
    end

    # Ranked broadcast: scalar * array * array
    value :gross_totals, input.items.price * input.items.quantity * input.base_multiplier

    # Ranked broadcast in trait: array compared to scalar
    trait :high_tax_items, (input.items.tax_rate > input.discount_rate)

    # Complex trait with ranked broadcast: array operations with scalar
    trait :expensive_items, (gross_totals > (input.base_multiplier * 100.0))

    # Cascade with ranked broadcast in CONDITIONS and RESULTS
    value :final_prices do
      # Condition: multiple traits (cascade_and will handle the AND logic)
      on expensive_items, high_tax_items, gross_totals * (1.0 + input.items.tax_rate) * input.discount_rate
      
      # Condition: simple trait with ranked broadcast result
      on expensive_items, gross_totals * input.discount_rate
      
      # Base case: ranked broadcast with scalar
      base gross_totals * input.base_multiplier * 0.5
    end

    # Another cascade with different ranked broadcast patterns
    value :tax_adjustments do
      # Condition uses trait, result has complex ranked broadcast
      on high_tax_items, (input.items.tax_rate * input.base_multiplier * input.discount_rate) + gross_totals
      
      # Base case: simple scalar
      base 10.0
    end
  end
end

puts "=" * 80
puts "COMPLEX RANKED BROADCAST CASCADE - STEP BY STEP"
puts "=" * 80

test_data = { 
  base_multiplier: 2.0,
  discount_rate: 0.1,
  items: [
    { price: 100.0, quantity: 2, tax_rate: 0.15, category: "electronics" },  # 100*2*2=400, high tax (0.15 > 0.1), expensive
    { price: 20.0, quantity: 3, tax_rate: 0.05, category: "books" },         # 20*3*2=120, low tax (0.05 < 0.1), not expensive  
    { price: 50.0, quantity: 1, tax_rate: 0.2, category: "luxury" }          # 50*1*2=100, high tax (0.2 > 0.1), not expensive
  ]
}

begin
  puts "\n=== STEP 1: BROADCAST DETECTOR ANALYSIS ==="
  analysis = IRTestHelper.get_analysis(ComplexRankedBroadcastCascade)
  detector_metadata = analysis.state[:detector_metadata]
  
  puts "\nFinal prices cascade metadata:"
  final_prices_meta = detector_metadata[:final_prices]
  require 'pp'
  puts PP.pp(final_prices_meta, "", 2).split("\n").map { |line| "  #{line}" }.join("\n")

  puts "\n=== STEP 2: IR GENERATION ==="  
  result = IRTestHelper.compile_schema(ComplexRankedBroadcastCascade, debug: false)
  
  final_prices_instruction = result[:ir][:instructions].find { |i| i[:name] == :final_prices }
  puts "\nFinal prices IR instruction:"
  puts PP.pp(final_prices_instruction, "", 2).split("\n").map { |line| "  #{line}" }.join("\n")

  puts "\n=== STEP 3: EXPECTED BEHAVIOR ==="
  puts "\nExpected intermediate values:"
  puts "  gross_totals: [400.0, 120.0, 100.0]   # price*quantity*base_multiplier"
  puts "  high_tax_items: [true, false, true]   # items.tax_rate > discount_rate"
  puts "  expensive_items: [true, false, false] # gross_totals > (base_multiplier * 100)"
  puts "\nExpected final_prices logic:"
  puts "  Item 0: expensive=true, high_tax=true   → 400*(1+0.15)*0.1 = 46.0"
  puts "  Item 1: expensive=false, high_tax=false → base case = 120*2*0.5 = 120.0"  
  puts "  Item 2: expensive=false, high_tax=true  → base case = 100*2*0.5 = 100.0"

  puts "\n=== STEP 4: ACTUAL EXECUTION ==="
  runner = result[:compiled_schema]
  
  gross_totals = runner.bindings[:gross_totals].call(test_data)
  high_tax_items = runner.bindings[:high_tax_items].call(test_data) 
  expensive_items = runner.bindings[:expensive_items].call(test_data)
  final_prices = runner.bindings[:final_prices].call(test_data)
  category_bonuses = runner.bindings[:category_bonuses].call(test_data)
  
  puts "  gross_totals: #{gross_totals.inspect}"
  puts "  high_tax_items: #{high_tax_items.inspect}"
  puts "  expensive_items: #{expensive_items.inspect}" 
  puts "  final_prices: #{final_prices.inspect}"
  puts "  category_bonuses: #{category_bonuses.inspect}"

rescue => e
  puts "Error: #{e.message}"
  puts "Backtrace: #{e.backtrace[0..5]}"
end