# frozen_string_literal: true

require "spec_helper"

# Test 2: Values and Traits with Sugar Syntax
class ValueTraitSchema
  extend Kumi::Schema

  schema do
    input do
      float :price
      integer :quantity
      string :category
    end

    # Using sugar syntax - arithmetic operations
    value :subtotal, input.price * input.quantity
    value :discount, input.subtotal * 0.1

    # Using explicit function syntax
    value :total, fn(:subtract, input.subtotal, input.discount)

    # Traits with sugar syntax
    trait :expensive, input.price > 100.0
    trait :bulk_order, input.quantity >= 10
    trait :electronics, input.category == "electronics"
  end
end

RSpec.describe "Text Parser: Values and Traits with Sugar Syntax" do
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

  it "produces identical AST for values with arithmetic operations" do
    text_dsl = <<~KUMI
      schema do
        input do
          float :price
          integer :quantity
          string :category
        end

        value :subtotal, input.price * input.quantity
        value :discount, input.subtotal * 0.1
        value :total, fn(:subtract, input.subtotal, input.discount)

        trait :expensive, input.price > 100.0
        trait :bulk_order, input.quantity >= 10
        trait :electronics, input.category == "electronics"
      end
    KUMI

    compare_asts(ValueTraitSchema, text_dsl)
  end
end