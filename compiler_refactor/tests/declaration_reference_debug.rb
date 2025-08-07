#!/usr/bin/env ruby

require_relative "../ir_test_helper"

module DeclarationReferenceDebug
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :items do
        float :value
      end
    end

    value :doubled, input.items.value * 2.0
    value :doubled_plus_one, doubled + 1.0
  end
end

puts "=" * 60
puts "DECLARATION REFERENCE DEBUG"
puts "=" * 60

test_data = { items: [{ value: 10.0 }, { value: 20.0 }] }

begin
  result = IRTestHelper.compile_schema(DeclarationReferenceDebug, debug: false)
  runner = result[:compiled_schema]
  
  puts "\nStep 1: Test 'doubled' (should work):"
  doubled_result = runner.bindings[:doubled].call(test_data)
  puts "  doubled result: #{doubled_result.inspect}"
  puts "  Type: #{doubled_result.class}"
  
  puts "\nStep 2: Test declaration reference compilation:"
  puts "Looking at how :doubled_plus_one compiles..."
  
  # Check the compiled binding for doubled_plus_one
  doubled_plus_one_binding = runner.bindings[:doubled_plus_one]
  puts "  doubled_plus_one binding exists: #{!doubled_plus_one_binding.nil?}"
  
  puts "\nStep 3: Manual operand compilation test:"
  puts "Simulating what compile_element_wise_with_accessors does..."
  
  # Simulate the operand compilation
  puts "\nOperand 1 (declaration_reference to :doubled):"
  puts "  Should return the result of calling doubled binding"
  manual_operand1 = runner.bindings[:doubled].call(test_data)
  puts "  manual_operand1: #{manual_operand1.inspect} (#{manual_operand1.class})"
  
  puts "\nOperand 2 (literal 1.0):"
  manual_operand2 = 1.0
  puts "  manual_operand2: #{manual_operand2.inspect} (#{manual_operand2.class})"
  
  puts "\nThe problem:"
  puts "  operand_values = [#{manual_operand1.inspect}, #{manual_operand2.inspect}]"
  puts "  operand_values.first.zip(*operand_values[1..-1])"
  puts "  #{manual_operand1.inspect}.zip(#{manual_operand2.inspect})"
  puts "  This fails because Float doesn't respond to :each"
  
  puts "\nStep 4: Try to execute doubled_plus_one:"
  doubled_plus_one_result = runner.bindings[:doubled_plus_one].call(test_data)
  puts "  doubled_plus_one result: #{doubled_plus_one_result.inspect}"
  
rescue => e
  puts "Error: #{e.message}"
  puts "  at: #{e.backtrace.first}"
  puts "  backtrace:"
  e.backtrace[0..5].each { |line| puts "    #{line}" }
end