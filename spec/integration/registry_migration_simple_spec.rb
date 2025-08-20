# frozen_string_literal: true

require 'spec_helper'

# Simple tests to verify RegistryV2 migration basics
RSpec.describe 'RegistryV2 Migration Basic Tests' do
  
  describe 'Basic operator normalization' do
    it 'handles simple comparisons' do
      schema = Module.new do
        extend Kumi::Schema
        
        schema do
          input do
            integer :age
          end
          
          trait :is_adult, input.age > 18
          value :status do
            on is_adult, "adult"
            base "minor"  
          end
        end
      end

      result = schema.from({ age: 25 })
      expect(result[:is_adult]).to eq(true)
      expect(result[:status]).to eq("adult")
      
      result = schema.from({ age: 15 })
      expect(result[:is_adult]).to eq(false)
      expect(result[:status]).to eq("minor")
    end
  end

  describe 'Basic aggregate functions' do
    it 'works with sum and max' do
      schema = Module.new do
        extend Kumi::Schema
        
        schema do
          input do
            array :numbers do
              integer :value
            end
          end
          
          value :total, fn(:sum, input.numbers.value)
          value :maximum, fn(:max, input.numbers.value)
        end
      end

      test_data = { numbers: [{ value: 10 }, { value: 5 }, { value: 15 }] }
      result = schema.from(test_data)
      
      # The new system returns unwrapped scalar values directly
      expect(result[:total]).to eq(30)
      expect(result[:maximum]).to eq(15)
    end
  end
  
  describe 'Basic cascade syntax (cascade_and desugar)' do
    it 'handles single condition in cascade (identity case)' do
      schema = Module.new do
        extend Kumi::Schema
        
        schema do
          input do
            boolean :active
            integer :score
          end
          
          trait :is_active, fn(:eq, input.active, true)
          trait :high_score, input.score > 80
          
          value :result do
            on is_active, "active_user"
            on high_score, "high_performer" 
            base "basic_user"
          end
        end
      end
      
      result = schema.from({ active: true, score: 60 })
      expect(result[:result]).to eq("active_user")
      
      result = schema.from({ active: false, score: 90 })
      expect(result[:result]).to eq("high_performer")
      
      result = schema.from({ active: false, score: 60 })
      expect(result[:result]).to eq("basic_user")
    end
  end

  describe 'Error handling' do
    it 'reports unknown functions' do
      expect {
        Module.new do
          extend Kumi::Schema
          
          schema do
            input do
              integer :x
            end
            
            value :result, fn(:unknown_function, input.x)
          end
        end
      }.to raise_error(/unknown function/)
    end
  end
end