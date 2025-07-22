#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'lib/kumi'

# This works - refinements active at top-level
puts "=== TOP-LEVEL CONTEXT (works) ==="
schema1 = Kumi.schema do
  input do
    integer :age
  end
  
  trait :adult, (input.age >= 18)  # Creates CallExpression 
end

runner1 = Kumi::Runner.new({age: 25}, schema1.runner.schema, schema1.runner.node_index)
puts "Adult trait result: #{runner1.fetch(:adult)}"

# This doesn't work - refinements not active in method context
puts "\n=== METHOD CONTEXT (doesn't work) ==="
def create_schema_in_method
  Kumi.schema do
    input do
      integer :age
    end
    
    trait :adult, (input.age >= 18)  # Falls back to regular Ruby (input.age >= 18) => true
  end
end

schema2 = create_schema_in_method
runner2 = Kumi::Runner.new({age: 25}, schema2.runner.schema, schema2.runner.node_index)
puts "Adult trait result: #{runner2.fetch(:adult)}"

# This works - using old syntax in method context
puts "\n=== METHOD CONTEXT WITH OLD SYNTAX (works) ==="
def create_schema_old_syntax
  Kumi.schema do
    input do
      integer :age
    end
    
    trait :adult, input.age, :>=, 18  # Uses old parser syntax
  end
end

schema3 = create_schema_old_syntax
runner3 = Kumi::Runner.new({age: 25}, schema3.runner.schema, schema3.runner.node_index)
puts "Adult trait result: #{runner3.fetch(:adult)}"
