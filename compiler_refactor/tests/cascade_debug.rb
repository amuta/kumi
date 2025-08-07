#!/usr/bin/env ruby

require_relative "../ir_test_helper"

module CascadeDebugTest
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
      on expensive_items, fn(:multiply, doubled_prices, 0.1)
      base 5.0
    end
  end
end

puts "=" * 60
puts "CASCADE DEBUG"
puts "=" * 60

test_data = { items: [{ price: 60.0 }, { price: 30.0 }] }

begin
  result = IRTestHelper.compile_schema(CascadeDebugTest, debug: false)
  
  puts "\nBroadcast detector metadata for cascade:"
  analysis_result = IRTestHelper.get_analysis(CascadeDebugTest)
  detector_metadata = analysis_result.state[:detector_metadata]
  cascade_meta = detector_metadata[:discount_rates]
  puts "  operation_type: #{cascade_meta[:operation_type]}"
  puts "  cascade_type: #{cascade_meta[:cascade_type]}" if cascade_meta[:cascade_type]
  puts "  _detected_element_wise: #{cascade_meta[:_detected_element_wise]}" if cascade_meta.key?(:_detected_element_wise)
  
  puts "\nFull cascade metadata:"
  require 'pp'
  puts PP.pp(cascade_meta, "", 2).split("\n").map { |line| "    #{line}" }.join("\n")
  
  if cascade_meta[:case_analyses]
    puts "\n  case analyses:"
    cascade_meta[:case_analyses].each_with_index do |analysis, i|
      puts "    [#{i}] is_element_wise: #{analysis[:is_element_wise]}"
      puts "        metadata: #{analysis[:metadata][:operation_type]}"
    end
  end
  
  puts "\nWhat factory gets - IR instruction:"
  discount_instruction = result[:ir][:instructions].find { |i| i[:name] == :discount_rates }
  puts "  instruction[:operation_type]: #{discount_instruction[:operation_type]}"
  puts "  compilation[:type]: #{discount_instruction[:compilation][:type]}"
  
  puts "\nWhat factory gets - compilation object:"
  compilation = discount_instruction[:compilation]
  puts PP.pp(compilation, "", 2).split("\n").map { |line| "    #{line}" }.join("\n")

  puts "\nIR Instructions:"
  result[:ir][:instructions].each do |instr|
    puts "\n#{instr[:name]}:"
    puts "  operation_type: #{instr[:operation_type]}"
    puts "  compilation_type: #{instr[:compilation][:type]}"
    
    if instr[:compilation][:type] == :cascade_expression
      puts "  cascade cases:"
      instr[:compilation][:cases].each_with_index do |c, i|
        puts "    [#{i}] condition: #{c[:condition].inspect}"
        puts "        result: #{c[:result].inspect}"
      end
    end
  end
  
  puts "\nFull IR dump:"
  require 'pp'
  require 'json'
  File.write("/tmp/cascade_ir.json", JSON.pretty_generate(result[:ir]))
  puts "  IR written to /tmp/cascade_ir.json"
  
  puts "\nExecution attempt:"
  runner = result[:compiled_schema]
  
  doubled_prices = runner.bindings[:doubled_prices].call(test_data)
  expensive_items = runner.bindings[:expensive_items].call(test_data)
  discount_rates = runner.bindings[:discount_rates].call(test_data)
  
  puts "  doubled_prices: #{doubled_prices.inspect}"
  puts "  expensive_items: #{expensive_items.inspect}"
  puts "  discount_rates: #{discount_rates.inspect}"

rescue => e
  puts "Error: #{e.message}"
  puts "  at: #{e.backtrace.first}"
end