#!/usr/bin/env ruby

require_relative "../ir_test_helper"

module DebugComplexCascade
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      float :base_multiplier     
      float :discount_rate       
      array :categories do
        string :name
        float :tax_rate          
      end
      array :items do
        float :price
        integer :quantity
      end
    end

    # Simple element-wise to start
    value :gross_totals, input.items.price * input.items.quantity * input.base_multiplier

    # Simple trait
    trait :expensive_items, (gross_totals > (input.base_multiplier * 100.0))

    # Simple cascade with complex result
    value :final_prices do
      on expensive_items, gross_totals * (1.0 + 0.15) * input.discount_rate
      base gross_totals * 0.5
    end
  end
end

puts "=" * 80
puts "DEBUG COMPLEX CASCADE - DETAILED IR ANALYSIS"
puts "=" * 80

test_data = { 
  base_multiplier: 2.0,
  discount_rate: 0.1,
  categories: [{ name: "electronics", tax_rate: 0.15 }],
  items: [{ price: 100.0, quantity: 2 }]
}

begin
  puts "\n=== STEP 1: BROADCAST DETECTOR ANALYSIS ==="
  analysis = IRTestHelper.get_analysis(DebugComplexCascade)
  detector_metadata = analysis.state[:detector_metadata]
  
  puts "\nAll detector metadata:"
  detector_metadata.each do |name, meta|
    puts "\n#{name}:"
    require 'pp'
    puts PP.pp(meta, "", 2).split("\n").map { |line| "  #{line}" }.join("\n")
  end

  puts "\n=== STEP 2: IR GENERATION ==="
  puts "Generating IR with TAC decomposition..."
  
  # Try to generate IR, catching errors but getting the IR structure
  begin
    result = IRTestHelper.compile_schema(DebugComplexCascade, debug: false)
    ir = result[:ir]
    puts "Compilation succeeded!"
  rescue => compile_error
    puts "Compilation failed (expected): #{compile_error.message}"
    # Still try to get the IR that was generated before the error
    # We'll create a simple test to get just the IR
    result = IRTestHelper.get_analysis(DebugComplexCascade)
    puts "Analysis succeeded, now generating IR..."
    
    # This might fail, but let's see what happens
    begin
      # Use the internal method from compile_schema
      syntax_tree = Kumi::Core::RubyParser::Dsl.build_syntax_tree(DebugComplexCascade) { DebugComplexCascade.schema_block }
      ir_generator = Kumi::Core::IRGenerator.new(syntax_tree, result)
      ir = ir_generator.generate
      puts "IR generation succeeded!"
    rescue => ir_error
      puts "IR generation failed: #{ir_error.message}"
      puts "Backtrace: #{ir_error.backtrace[0..2]}"
      return
    end
  end
  
  puts "\nGenerated IR structure:"
  puts "- Accessors: #{ir[:accessors].keys}"
  puts "- Instructions count: #{ir[:instructions].length}"
  puts "\nAll instructions:"
  
  ir[:instructions].each_with_index do |instruction, idx|
    puts "\n--- Instruction #{idx}: #{instruction[:name]} ---"
    puts "Type: #{instruction[:type]}"
    puts "Operation Type: #{instruction[:operation_type]}"
    puts "Data Type: #{instruction[:data_type].inspect}"
    puts "Temp: #{instruction[:temp] || false}"
    puts "Compilation:"
    puts PP.pp(instruction[:compilation], "", 2).split("\n").map { |line| "  #{line}" }.join("\n")
  end

  puts "\n=== STEP 3: COMPILATION ATTEMPT ==="
  puts "Attempting to compile each instruction..."
  
  ir_compiler = Kumi::Core::IRCompiler.new(ir)
  
  ir[:instructions].each_with_index do |instruction, idx|
    puts "\n--- Compiling instruction #{idx}: #{instruction[:name]} ---"
    begin
      case instruction[:operation_type]
      when :scalar
        puts "  -> Compiling as scalar operation"
        puts "  -> Compilation type: #{instruction[:compilation][:type]}"
        result = ir_compiler.send(:compile_scalar_operation, instruction)
        puts "  -> SUCCESS: #{result.class}"
      when :element_wise
        puts "  -> Compiling as element-wise operation"
        puts "  -> Compilation type: #{instruction[:compilation][:type]}"
        result = ir_compiler.send(:compile_element_wise_operation, instruction)
        puts "  -> SUCCESS: #{result.class}"
      else
        puts "  -> Unknown operation type: #{instruction[:operation_type]}"
      end
    rescue => e
      puts "  -> ERROR: #{e.message}"
      puts "  -> Backtrace: #{e.backtrace[0..2]}"
      puts "  -> This is where our error occurs!"
      break
    end
  end

rescue => e
  puts "Error: #{e.message}"
  puts "Backtrace: #{e.backtrace[0..5]}"
end