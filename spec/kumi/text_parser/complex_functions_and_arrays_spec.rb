# frozen_string_literal: true

require "spec_helper"

# Test 3: Complex DSL Features - Arrays, Functions, Multiple Expressions
class ComplexFeaturesSchema
  extend Kumi::Schema

  schema do
    input do
      array :line_items, elem: { type: :float }
      float :tax_rate, domain: 0.0..1.0
      string :customer_tier, domain: %w[bronze silver gold]
      boolean :is_weekend
    end

    # Array operations
    value :total, fn(:sum, input.line_items)
    value :item_count, fn(:size, input.line_items)
    value :average_item, fn(:divide, input.total, input.item_count)

    # Multiple function arguments
    value :tax_amount, fn(:multiply, input.total, input.tax_rate)
    value :final_total, fn(:add, input.total, input.tax_amount)

    # Traits with multiple conditions
    trait :premium_customer, input.customer_tier == "gold"
    trait :large_order, input.total > 1000.0
    trait :weekend_order, input.is_weekend == true
  end
end

RSpec.describe "Text Parser: Complex Functions and Arrays" do
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

  it "produces identical AST for complex DSL features" do
    text_dsl = <<~KUMI
      schema do
        input do
          array :line_items, elem: { type: :float }
          float :tax_rate, domain: 0.0..1.0
          string :customer_tier, domain: %w[bronze silver gold]
          boolean :is_weekend
        end

        value :total, fn(:sum, input.line_items)
        value :item_count, fn(:size, input.line_items)
        value :average_item, fn(:divide, input.total, input.item_count)
        value :tax_amount, fn(:multiply, input.total, input.tax_rate)
        value :final_total, fn(:add, input.total, input.tax_amount)

        trait :premium_customer, input.customer_tier == "gold"
        trait :large_order, input.total > 1000.0  
        trait :weekend_order, input.is_weekend == true
      end
    KUMI

    compare_asts(ComplexFeaturesSchema, text_dsl)
  end
end