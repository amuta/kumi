# frozen_string_literal: true

require "spec_helper"

# Test combination of cascades and nested arrays
class CascadesWithArraysSchema
  extend Kumi::Schema
  
  schema do
    input do
      array :orders do
        string :customer_type, domain: %w[premium standard basic]
        float :order_value
        array :items do
          string :category
          float :price
          integer :quantity
        end
      end
      float :company_revenue_target
    end

    # Vectorized computations
    value :item_subtotals, input.orders.items.price * input.orders.items.quantity
    value :order_totals, fn(:sum, item_subtotals)
    value :total_revenue, fn(:sum, order_totals)

    # Traits based on vectorized data
    trait :premium_customers, input.orders.customer_type == "premium"
    trait :high_value_orders, input.orders.order_value > 1000.0
    trait :luxury_items, input.orders.items.price > 500.0

    # Cascades using traits from vectorized operations
    value :customer_discount do
      on premium_customers, 0.15
      on high_value_orders, 0.10
      base 0.05
    end

    value :shipping_method do
      on premium_customers, "express"
      on high_value_orders, "priority"
      base "standard"
    end

    # Mixed traits and cascades
    trait :revenue_target_met, total_revenue >= input.company_revenue_target
    
    value :performance_status do
      on revenue_target_met, "Excellent"
      base "Needs Improvement"
    end
  end
end

RSpec.describe "Text Parser: Cascades with Arrays" do
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

  it "produces identical AST for cascades combined with nested arrays" do
    text_dsl = <<~KUMI
      schema do
        input do
          array :orders do
            string :customer_type, domain: %w[premium standard basic]
            float :order_value
            array :items do
              string :category
              float :price
              integer :quantity
            end
          end
          float :company_revenue_target
        end

        value :item_subtotals, input.orders.items.price * input.orders.items.quantity
        value :order_totals, fn(:sum, item_subtotals)
        value :total_revenue, fn(:sum, order_totals)

        trait :premium_customers, input.orders.customer_type == "premium"
        trait :high_value_orders, input.orders.order_value > 1000.0
        trait :luxury_items, input.orders.items.price > 500.0

        value :customer_discount do
          on premium_customers, 0.15
          on high_value_orders, 0.10
          base 0.05
        end

        value :shipping_method do
          on premium_customers, "express"
          on high_value_orders, "priority"
          base "standard"
        end

        trait :revenue_target_met, total_revenue >= input.company_revenue_target
        
        value :performance_status do
          on revenue_target_met, "Excellent"
          base "Needs Improvement"
        end
      end
    KUMI

    compare_asts(CascadesWithArraysSchema, text_dsl)
  end
end