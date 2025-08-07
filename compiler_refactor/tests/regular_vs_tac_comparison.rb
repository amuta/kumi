#!/usr/bin/env ruby

require_relative "../ir_test_helper"
require_relative "tac_test_helper"

# Regular IR Generator Test
module RegularIRTest
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :items do
        float :value
      end
    end

    # Step 1: Simple element-wise
    value :doubled, input.items.value * 2.0
    # Step 2: Declaration reference + scalar (SAME PATTERN as TAC)
    value :doubled_plus_one, doubled + 1.0
  end
end

# TAC System Test  
module TACTest
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :items do
        float :value
      end
    end

    # Complex expression that TAC flattens into same pattern
    value :complex_nested, (input.items.value * 2.0) + 1.0
  end
end

puts "=" * 80
puts "REGULAR IR vs TAC COMPARISON"
puts "=" * 80

test_data = { items: [{ value: 10.0 }, { value: 20.0 }] }

puts "\n" + "=" * 40
puts "REGULAR IR GENERATOR"
puts "=" * 40

begin
  regular_result = IRTestHelper.compile_schema(RegularIRTest, debug: false)
  regular_runner = regular_result[:compiled_schema]
  
  puts "\nRegular IR Instructions:"
  regular_result[:ir][:instructions].each do |instr|
    if instr[:name] == :doubled_plus_one
      puts "\n#{instr[:name]}:"
      puts "  operation_type: #{instr[:operation_type]}"
      puts "  compilation_type: #{instr[:compilation][:type]}"
      puts "  operands:"
      instr[:compilation][:operands].each_with_index do |op, i|
        puts "    [#{i}] type: #{op[:type]}, details: #{op.inspect}"
      end
    end
  end
  
  puts "\nRegular execution:"
  doubled_result = regular_runner.bindings[:doubled].call(test_data)
  doubled_plus_one_result = regular_runner.bindings[:doubled_plus_one].call(test_data)
  puts "  doubled: #{doubled_result.inspect}"
  puts "  doubled_plus_one: #{doubled_plus_one_result.inspect}"
  
rescue => e
  puts "Regular IR failed: #{e.message}"
  puts "  at: #{e.backtrace.first}"
end

puts "\n" + "=" * 40
puts "TAC SYSTEM" 
puts "=" * 40

begin
  tac_result = TACTestHelper.compile_schema(TACTest, debug: false)
  tac_runner = tac_result[:compiled_schema]
  
  puts "\nTAC Instructions:"
  tac_result[:tac_ir][:instructions].each do |instr|
    puts "\n#{instr[:name]} (temp: #{instr[:temp]}):"
    puts "  operation_type: #{instr[:operation_type]}"
    puts "  compilation_type: #{instr[:compilation][:type]}"
    puts "  operands:"
    instr[:compilation][:operands].each_with_index do |op, i|
      puts "    [#{i}] type: #{op[:type]}, details: #{op.inspect}"
    end
  end
  
  puts "\nTAC execution:"
  temp_result = tac_runner.bindings[:__temp_1].call(test_data) if tac_runner.bindings[:__temp_1]
  complex_result = tac_runner.bindings[:complex_nested].call(test_data)
  puts "  __temp_1: #{temp_result.inspect}" if temp_result
  puts "  complex_nested: #{complex_result.inspect}"
  
rescue => e
  puts "TAC failed: #{e.message}"
  puts "  at: #{e.backtrace.first}"
end

puts "\n" + "=" * 40
puts "COMPARISON ANALYSIS"
puts "=" * 40

puts "\nPattern Analysis:"
puts "Regular: doubled (array) + 1.0 (scalar)"
puts "TAC:     __temp_1 (array) + multiplier (scalar)" 
puts "\nBoth should use IDENTICAL compilation logic!"

expected = [21.0, 41.0]
puts "\nExpected result for both: #{expected.inspect}"