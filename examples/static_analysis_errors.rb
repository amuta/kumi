# frozen_string_literal: true

# Static Analysis Error Examples
# This file demonstrates various errors that Kumi catches during schema definition

require_relative "../lib/kumi"

puts "=== Kumi Static Analysis Examples ===\n"
puts "All errors caught during schema definition, before any data processing!\n\n"

# Example 1: Circular Dependency Detection
puts "1. Circular Dependency Detection:"
puts "   Code with circular references between values..."
begin
  module CircularDependency
    extend Kumi::Schema
    
    schema do
      input { float :base }
      
      value :monthly_rate, yearly_rate / 12
      value :yearly_rate, monthly_rate * 12
    end
  end
rescue Kumi::Errors::SemanticError => e
  puts "   → #{e.message}"
end

puts "\n" + "="*60 + "\n"

# Example 2: Impossible Logic Detection (UnsatDetector)
puts "2. Impossible Logic Detection:"
puts "   Code with contradictory conditions..."
begin
  module ImpossibleLogic
    extend Kumi::Schema
    
    schema do
      input { integer :age }
      
      trait :child, input.age < 13
      trait :adult, input.age >= 18
      
      # This combination can never be true
      value :status do
        on child & adult, "Impossible!"
        base "Normal"
      end
    end
  end
rescue Kumi::Errors::SemanticError => e
  puts "   → #{e.message}"
end

puts "\n" + "="*60 + "\n"

# Example 3: Type System Validation
puts "3. Type Mismatch Detection:"
puts "   Code trying to add incompatible types..."
begin
  module TypeMismatch
    extend Kumi::Schema
    
    schema do
      input do
        string :name
        integer :age
      end
      
      # String + Integer type mismatch
      value :invalid_sum, input.name + input.age
    end
  end
rescue Kumi::Errors::TypeError => e
  puts "   → #{e.message}"
end

puts "\n" + "="*60 + "\n"

# Example 4: Domain Constraint Analysis
puts "4. Domain Constraint Violations:"
puts "   Code using values outside declared domains..."
begin
  module DomainViolation
    extend Kumi::Schema
    
    schema do
      input do
        integer :score, domain: 0..100
        string :grade, domain: %w[A B C D F]
      end
      
      # 150 is outside the domain 0..100
      trait :impossible_score, input.score == 150
    end
  end
rescue Kumi::Errors::SemanticError => e
  puts "   → #{e.message}"
end

puts "\n" + "="*60 + "\n"

# Example 5: Undefined Reference Detection
puts "5. Undefined Reference Detection:"
puts "   Code referencing non-existent declarations..."
begin
  module UndefinedReference
    extend Kumi::Schema
    
    schema do
      input { integer :amount }
      
      # References a trait that doesn't exist
      value :result, ref(:nonexistent_trait) ? 100 : 0
    end
  end
rescue Kumi::Errors::SemanticError => e
  puts "   → #{e.message}"
end

puts "\n" + "="*60 + "\n"

# Example 6: Invalid Function Usage
puts "6. Invalid Function Detection:"
puts "   Code using non-existent functions..."
begin
  module InvalidFunction
    extend Kumi::Schema
    
    schema do
      input { string :text }
      
      # Function doesn't exist in registry
      value :result, fn(:nonexistent_function, input.text)
    end
  end
rescue Kumi::Errors::TypeError => e
  puts "   → #{e.message}"
end

puts "\n" + "="*60 + "\n"

# Example 7: Complex Schema with Multiple Issues
puts "7. Multiple Issues Detected:"
puts "   Complex schema with several problems..."
begin
  module MultipleIssues
    extend Kumi::Schema
    
    schema do
      input { integer :value, domain: 1..10 }
      
      # Issue 1: Circular dependency
      value :a, b + 1
      value :b, c + 1  
      value :c, a + 1
      
      # Issue 2: Impossible domain condition
      trait :impossible, (input.value > 10) & (input.value < 5)
      
      # Issue 3: Undefined reference
      value :result, ref(:undefined_declaration)
    end
  end
rescue Kumi::Errors::SemanticError => e
  puts "   → " + e.message.split("\n").join("\n   → ")
end

puts "\n" + "="*60 + "\n"
puts "Summary:"
puts "• Circular dependencies caught before infinite loops"
puts "• Impossible logic detected through constraint analysis"  
puts "• Type mismatches found during type inference"
puts "• Domain violations identified through static analysis"
puts "• Undefined references caught during name resolution"
puts "• Invalid functions detected during compilation"
puts "• Multiple issues reported together with precise locations"
puts "\nAll validation happens during schema definition - no runtime surprises!"