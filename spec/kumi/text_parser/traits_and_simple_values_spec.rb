# frozen_string_literal: true

require "spec_helper"

# Test 4: Cascade Expressions - Conditional Logic with on/base syntax
class CascadeSchema
  extend Kumi::Schema

  schema do
    input do
      integer :age, domain: 0..120
      string :membership, domain: %w[bronze silver gold]
      float :total_spent, domain: 0.0..10000.0
    end

    trait :adult, (input.age >= 18)
    trait :premium, (input.membership == "gold")
    trait :high_spender, (input.total_spent > 1000.0)

    # Simple value for now - cascades will be added later
    value :discount_rate, fn(:multiply, input.total_spent, 0.01)
  end
end

RSpec.describe "Text Parser: Traits and Simple Values" do
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

  it "produces identical AST for traits and simple values" do
    text_dsl = <<~KUMI
      schema do
        input do
          integer :age, domain: 0..120
          string :membership, domain: %w[bronze silver gold]
          float :total_spent, domain: 0.0..10000.0
        end

        trait :adult, (input.age >= 18)
        trait :premium, (input.membership == "gold")
        trait :high_spender, (input.total_spent > 1000.0)

        value :discount_rate, fn(:multiply, input.total_spent, 0.01)
      end
    KUMI

    compare_asts(CascadeSchema, text_dsl)
  end
end