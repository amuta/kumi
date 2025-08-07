#!/usr/bin/env ruby

require_relative "../ir_test_helper"

module CascadeWithRankedBroadcast
  # CascadeWithRankedBroadcast
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      float :multiplier
      array :items do
        float :price
      end
    end

    # element-wise with ranked broadcast
    value :doubled, input.items.price * 2 * input.multiplier

    # Simple trait
    trait :expensive, (input.items.price > 50.0)

    # Simple cascade with one element-wise result, one scalar result
    value :discounts do
      on expensive, doubled * 0.1  # element-wise result
      base 5.0                     # scalar result
    end
  end
end

puts "=" * 80
puts "SIMPLE CASCADE DEBUG - STEP BY STEP"
puts "=" * 80

test_data = { items: [{ price: 60.0 }, { price: 30.0 }], multiplier: 2.0 }

begin
  puts "\n=== STEP 1: BROADCAST DETECTOR ANALYSIS ==="
  analysis = IRTestHelper.get_analysis CascadeWithRankedBroadcast

  detector_metadata = analysis.state[:detector_metadata]

  puts "\nDiscounts cascade metadata from BroadcastDetector:"
  discounts_meta = detector_metadata[:discounts]
  require "pp"
  puts PP.pp(discounts_meta, "", 2).split("\n").map { |line| "  #{line}" }.join("\n")

  puts "\n=== STEP 2: IR GENERATION ==="
  result = IRTestHelper.compile_schema(CascadeWithRankedBroadcast, debug: false)

  discount_instruction = result[:ir][:instructions].find { |i| i[:name] == :discounts }
  puts "\nDiscounts IR instruction:"
  puts PP.pp(discount_instruction, "", 2).split("\n").map { |line| "  #{line}" }.join("\n")

  puts "\n=== STEP 3: WHAT FACTORY RECEIVES ==="
  compilation = discount_instruction[:compilation]
  puts "\nCompilation object passed to CascadeLambdaFactory:"
  puts PP.pp(compilation, "", 2).split("\n").map { |line| "  #{line}" }.join("\n")

  puts "\n=== STEP 4: EXPECTED VS ACTUAL ==="
  puts "\nExpected behavior:"
  puts "  doubled: [240.0, 120.0]"
  puts "  expensive: [true, false]"
  puts "  discounts should be:"
  puts "    - Item 0: expensive=true → doubled[0] * 0.1 = 12.0"
  puts "    - Item 1: expensive=false → base case = 5.0"
  puts "    - Result: [12.0, 5.0]"

  puts "\nActual execution:"
  runner = result[:compiled_schema]
  doubled = runner.bindings[:doubled].call(test_data)
  expensive = runner.bindings[:expensive].call(test_data)
  discounts = runner.bindings[:discounts].call(test_data)

  puts "  doubled: #{doubled.inspect}"
  puts "  expensive: #{expensive.inspect}"
  puts "  discounts: #{discounts.inspect}"
rescue StandardError => e
  puts "Error: #{e.message}"
  puts "Backtrace: #{e.backtrace[0..3]}"
end
