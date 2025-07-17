#!/usr/bin/env ruby

require_relative 'lib/kumi'

# Test how input block typing and type inference interact
def test_input_inference_interaction
  puts "=== Testing Input Block Typing vs Type Inference ==="
  
  # Test 1: Input block with explicit typing
  puts "\n1. Testing explicit input typing:"
  schema1 = Kumi.schema do
    input do
      key :age, type: Kumi::Types::INT
      key :name, type: Kumi::Types::STRING
    end
    
    value :adult_status, fn(:if, 
      fn(:>=, input.age, 18), 
      "adult", 
      "minor"
    )
    
    value :greeting, fn(:concat, "Hello ", input.name)
  end
  
  puts "Input field types from input_meta:"
  input_meta = schema1.analysis.state[:input_meta]
  input_meta.each do |field, meta|
    puts "  #{field}: #{meta[:type]}"
  end
  
  puts "Inferred types from type inferencer:"
  inferred_types = schema1.analysis.decl_types
  inferred_types.each do |name, type|
    puts "  #{name}: #{type}"
  end
  
  # Test 2: Input field without explicit typing
  puts "\n2. Testing input field without explicit typing:"
  schema2 = Kumi.schema do
    input do
      key :score  # No explicit type
    end
    
    value :passed, fn(:>, input.score, 60)
  end
  
  puts "Input field types from input_meta:"
  input_meta2 = schema2.analysis.state[:input_meta]
  input_meta2.each do |field, meta|
    puts "  #{field}: #{meta[:type]}"
  end
  
  puts "Inferred types:"
  inferred_types2 = schema2.analysis.decl_types
  inferred_types2.each do |name, type|
    puts "  #{name}: #{type}"
  end
  
  # Test 3: Test runtime behavior
  puts "\n3. Testing runtime behavior:"
  
  # For schema1, recreate it and run
  schema1 = Kumi.schema do
    input do
      key :age, type: Kumi::Types::INT
      key :name, type: Kumi::Types::STRING
    end
    
    value :adult_status, fn(:if, 
      fn(:>=, input.age, 18), 
      "adult", 
      "minor"
    )
    
    value :greeting, fn(:concat, "Hello ", input.name)
  end
  
  runner1 = Kumi.from({ age: 25, name: "Alice" })
  result1 = { adult_status: runner1.fetch(:adult_status), greeting: runner1.fetch(:greeting) }
  puts "Result 1: #{result1}"
  
  # For schema2, recreate it and run
  schema2 = Kumi.schema do
    input do
      key :score  # No explicit type
    end
    
    value :passed, fn(:>, input.score, 60)
  end
  
  runner2 = Kumi.from({ score: 85 })
  result2 = { passed: runner2.fetch(:passed) }
  puts "Result 2: #{result2}"
  
  puts "\n=== Test Complete ==="
end

test_input_inference_interaction