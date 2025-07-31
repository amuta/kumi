# frozen_string_literal: true

require "spec_helper"

# Comprehensive Text Parser Tests - Extracted from existing integration specs
# Tests complex DSL features found in array_broadcasting_comprehensive_spec.rb

class BasicElementWiseSchema
  extend Kumi::Schema

  schema do
    input do
      array :items do
        float   :price
        integer :quantity
        string  :category
      end
      float :tax_rate
      float :multiplier
    end

    # Basic arithmetic operations
    value :subtotals, input.items.price * input.items.quantity
    value :discounted_prices, input.items.price * 0.9
    value :scaled_prices, input.items.price * input.multiplier

    # Comparison operations  
    trait :expensive, input.items.price > 100.0
    trait :high_quantity, input.items.quantity >= 5
    trait :is_electronics, input.items.category == "electronics"

    # Conditional operations using fn(:if)
    value :conditional_prices, fn(:if, expensive, input.items.price * 0.8, input.items.price)
  end
end

class StringOperationsSchema
  extend Kumi::Schema

  schema do
    input do
      string :name
      string :email
      array :tags, elem: { type: :string }
      string :status, domain: %w[active inactive pending]
    end

    # String operations
    trait :has_name, input.name != ""
    trait :valid_email, fn(:contains?, input.email, "@")
    trait :is_active, input.status == "active"
    trait :has_tags, fn(:size, input.tags) > 0

    # String functions
    value :name_length, fn(:string_length, input.name)
    value :uppercase_name, fn(:upcase, input.name)
    value :first_tag, fn(:first, input.tags)
  end
end

class MathematicalOperationsSchema
  extend Kumi::Schema

  schema do
    input do
      float :base_amount
      float :rate
      integer :years
      array :values, elem: { type: :float }
    end

    # Mathematical operations
    value :compound_interest, input.base_amount * input.rate
    value :total_values, fn(:sum, input.values)
    value :max_value, fn(:max, input.values) 
    value :min_value, fn(:min, input.values)
    value :value_count, fn(:size, input.values)

    # Mathematical comparisons
    trait :high_rate, input.rate > 0.05
    trait :long_term, input.years >= 10
    trait :has_high_values, fn(:max, input.values) > 1000.0
  end
end

RSpec.describe "Text Parser: Comprehensive DSL Features" do
  def compare_asts(ruby_schema_class, text_dsl)
    ruby_ast = ruby_schema_class.__syntax_tree__
    text_ast = Kumi::TextParser.parse(text_dsl)
    
    expect(normalize_ast(text_ast)).to eq(normalize_ast(ruby_ast))
  end
  
  def normalize_ast(ast)
    normalize_node(ast)
  end
  
  def normalize_node(node)
    case node
    when Array
      node.map { |item| normalize_node(item) }
    when Hash
      node.except(:loc, :location).transform_values { |v| normalize_node(v) }
    when Struct
      members = node.class.members
      result = {}
      
      members.each do |member|
        next if [:loc, :location].include?(member)
        
        value = node.public_send(member)
        result[member] = normalize_node(value)
      end
      
      result.merge(node_type: node.class.name)
    else
      node
    end
  end

  describe "String operations and functions" do
    it "produces identical AST for string DSL features" do
      text_dsl = <<~KUMI
        schema do
          input do
            string :name
            string :email
            array :tags, elem: { type: :string }
            string :status, domain: %w[active inactive pending]
          end

          trait :has_name, input.name != ""
          trait :valid_email, fn(:contains?, input.email, "@")
          trait :is_active, input.status == "active"
          trait :has_tags, fn(:size, input.tags) > 0
          value :name_length, fn(:string_length, input.name)
          value :uppercase_name, fn(:upcase, input.name)
          value :first_tag, fn(:first, input.tags)
        end
      KUMI

      puts "Getting Ruby AST..."
      ruby_ast = StringOperationsSchema.__syntax_tree__
      puts "Got Ruby AST: #{ruby_ast.class}"
      
      puts "Getting Text AST..."  
      text_ast = Kumi::TextParser.parse(text_dsl)
      puts "Got Text AST: #{text_ast.class}"
      
      puts "Normalizing ASTs..."
      normalized_text = normalize_ast(text_ast)
      normalized_ruby = normalize_ast(ruby_ast)
      
      puts "Comparing ASTs..."
      expect(normalized_text).to eq(normalized_ruby)
    end
  end

  describe "Mathematical operations and aggregations" do
    it "produces identical AST for mathematical DSL features" do
      text_dsl = <<~KUMI
        schema do
          input do
            float :base_amount
            float :rate
            integer :years
            array :values, elem: { type: :float }
          end

          value :compound_interest, input.base_amount * input.rate
          value :total_values, fn(:sum, input.values)
          value :max_value, fn(:max, input.values)
          value :min_value, fn(:min, input.values)
          value :value_count, fn(:size, input.values)
          trait :high_rate, input.rate > 0.05
          trait :long_term, input.years >= 10
          trait :has_high_values, fn(:max, input.values) > 1000.0
        end
      KUMI

      compare_asts(MathematicalOperationsSchema, text_dsl)
    end
  end

  # Note: This test will fail until nested array block parsing is implemented
  describe "Complex element-wise operations (requires nested arrays)" do
    it "produces identical AST for basic element-wise operations" do
      text_dsl = <<~KUMI
        schema do
          input do
            array :items do
              float   :price
              integer :quantity
              string  :category
            end
            float :tax_rate
            float :multiplier
          end

          value :subtotals, input.items.price * input.items.quantity
          value :discounted_prices, input.items.price * 0.9
          value :scaled_prices, input.items.price * input.multiplier
          trait :expensive, input.items.price > 100.0
          trait :high_quantity, input.items.quantity >= 5
          trait :is_electronics, input.items.category == "electronics"
          value :conditional_prices, fn(:if, expensive, input.items.price * 0.8, input.items.price)
        end
      KUMI

      # Nested array parsing is now implemented!
      compare_asts(BasicElementWiseSchema, text_dsl)
    end
  end
end