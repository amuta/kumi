#!/usr/bin/env ruby

require_relative 'lib/kumi'

def test_type_conflicts
  puts "=== Testing Potential Type Conflicts ==="
  
  # Test 1: Check what happens when we have a field with explicit type but use it in a way that suggests another type
  puts "\n1. Testing explicit INT type used in string concatenation:"
  begin
    schema1 = Kumi.schema do
      input do
        key :age, type: Kumi::Types::INT  # Explicit INT type
      end
      
      # Use the INT field in string concatenation - this should work due to type coercion in Ruby
      value :message, fn(:concat, "Age is: ", input.age)
    end
    
    puts "Input meta: #{schema1.analysis.state[:input_meta]}"
    puts "Inferred types: #{schema1.analysis.decl_types}"
    
    # Test runtime behavior
    runner = Kumi.from({ age: 25 })
    result = runner.fetch(:message)
    puts "Runtime result: #{result}"
    puts "✓ No conflict - works as expected"
  rescue => e
    puts "✗ Error: #{e.message}"
  end
  
  # Test 2: Check what happens with conflicting type declarations
  puts "\n2. Testing conflicting type declarations:"
  begin
    schema2 = Kumi.schema do
      input do
        key :score, type: Kumi::Types::INT
        key :score, type: Kumi::Types::STRING  # Conflicting type declaration
      end
      
      value :result, input.score
    end
    puts "✗ Should have failed with conflicting types"
  rescue => e
    puts "✓ Correctly caught conflict: #{e.message}"
  end
  
  # Test 3: Check undeclared input field usage
  puts "\n3. Testing undeclared input field usage:"
  begin
    schema3 = Kumi.schema do
      input do
        key :name, type: Kumi::Types::STRING
      end
      
      # Using undeclared field - should work but with ANY type
      value :result, input.undeclared_field
    end
    puts "✗ Should have failed with undeclared field"
  rescue => e
    puts "✓ Correctly caught undeclared field: #{e.message}"
  end
  
  # Test 4: Function type checking with explicit input types
  puts "\n4. Testing function type checking with explicit input types:"
  begin
    schema4 = Kumi.schema do
      input do
        key :value, type: Kumi::Types::STRING
      end
      
      # Using STRING in a numeric function - should this pass or fail?
      value :result, fn(:add, input.value, 10)
    end
    puts "Schema created successfully"
    puts "Input meta: #{schema4.analysis.state[:input_meta]}"
    puts "Inferred types: #{schema4.analysis.decl_types}"
    puts "⚠️ Type checking didn't catch STRING + INT incompatibility"
  rescue => e
    puts "✓ Correctly caught type mismatch: #{e.message}"
  end
  
  # Test 5: Check what type inferencer returns for explicit input types
  puts "\n5. Testing type inferencer behavior with explicit input types:"
  schema5 = Kumi.schema do
    input do
      key :num, type: Kumi::Types::INT
      key :text, type: Kumi::Types::STRING
    end
    
    value :direct_num, input.num
    value :direct_text, input.text
    value :computed, fn(:add, input.num, 5)
  end
  
  puts "Input meta types:"
  schema5.analysis.state[:input_meta].each do |field, meta|
    puts "  #{field}: #{meta[:type]}"
  end
  
  puts "Inferred types:"
  schema5.analysis.decl_types.each do |name, type|
    puts "  #{name}: #{type}"
  end
  
  puts "\n=== Test Complete ==="
end

test_type_conflicts