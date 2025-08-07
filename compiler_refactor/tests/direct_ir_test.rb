#!/usr/bin/env ruby

require_relative "../ir_test_helper"
require_relative "../ir_compiler"

# Test direct IR compilation with manually created IR
puts "=== Testing Direct IR Compilation ==="

# Create IR structure similar to what TAC generates but with accessors
test_ir = {
  accessors: {
    "items:structure" => ->(ctx) { ctx[:items] },
    "items:element" => ->(ctx) { ctx[:items] },
    "items:flattened" => ->(ctx) { ctx[:items].flatten },
    "items.value:structure" => ->(ctx) { ctx[:items].map { |item| item[:value] } },
    "items.value:element" => ->(ctx) { ctx[:items].map { |item| item[:value] } },
    "items.weight:element" => ->(ctx) { ctx[:items].map { |item| item[:weight] } },
    "multiplier:structure" => ->(ctx) { ctx[:multiplier] }
  },
  instructions: [
    {
      name: :__temp_1,
      operation_type: :element_wise,
      compilation: {
        type: :call_expression,
        function: :multiply,
        operands: [
          { type: :input_element_reference, path: [:items, :weight], accessor: "items.weight:element" },
          { type: :literal, value: 2.0 }
        ]
      },
      temp: true
    },
    {
      name: :inline_chain,
      operation_type: :element_wise,
      compilation: {
        type: :call_expression,
        function: :add,
        operands: [
          { type: :declaration_reference, name: :__temp_1 },
          { type: :input_reference, name: :multiplier, accessor: "multiplier:structure" }
        ]
      },
      temp: false
    }
  ]
}

test_data = {
  items: [
    { value: 10.0, weight: 1.0 },
    { value: 20.0, weight: 2.0 },
    { value: 30.0, weight: 3.0 }
  ],
  multiplier: 5.0
}

puts "Input data:"
puts "  items: #{test_data[:items]}"
puts "  multiplier: #{test_data[:multiplier]}"
puts

begin
  # Compile the IR directly
  compiler = Kumi::Core::IRCompiler.new(test_ir)
  compiled_schema = compiler.compile
  
  puts "Compilation successful!"
  puts "Created bindings: #{compiled_schema.bindings.keys.inspect}"
  
  # Test execution
  puts "\nTesting execution:"
  
  # Should be [(1*2)+5, (2*2)+5, (3*2)+5] = [7, 9, 11]
  expected_inline_chain = [7.0, 9.0, 11.0]
  
  temp_result = compiled_schema.bindings[:__temp_1].call(test_data)
  puts "__temp_1 result: #{temp_result.inspect}"
  puts "  (should be [2.0, 4.0, 6.0])"
  
  inline_chain_result = compiled_schema.bindings[:inline_chain].call(test_data)
  puts "inline_chain result: #{inline_chain_result.inspect}"
  puts "  (should be #{expected_inline_chain.inspect})"
  
  success = inline_chain_result == expected_inline_chain
  puts "\n#{success ? '✓ PASS' : '✗ FAIL'}: Direct IR compilation and execution"
  
rescue => e
  puts "Failed: #{e.message}"
  puts "  at: #{e.backtrace.first}"
end