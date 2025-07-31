# frozen_string_literal: true

require "spec_helper"

# Test multiple levels of array nesting
class DeepNestedArraySchema
  extend Kumi::Schema
  
  schema do
    input do
      array :departments do
        string :name
        string :location
        array :teams do
          string :team_name
          integer :team_size
          array :members do
            string :member_name
            float :salary
            integer :years_experience
          end
        end
      end
      float :company_budget
    end

    # Vectorized operations at different levels
    value :all_salaries, input.departments.teams.members.salary
    value :total_salary_cost, fn(:sum, all_salaries)
    trait :over_budget, total_salary_cost > input.company_budget
  end
end

class MixedNestedStructuresSchema
  extend Kumi::Schema
  
  schema do
    input do
      array :orders do
        string :order_id
        string :customer_name
        array :line_items do
          string :product_name
          float :unit_price
          integer :quantity
          string :category
        end
        float :discount_percentage
      end
      string :store_region, domain: %w[north south east west]
      float :tax_rate
    end

    # Multi-level vectorized calculations
    value :line_subtotals, input.orders.line_items.unit_price * input.orders.line_items.quantity
    value :total_revenue, fn(:sum, line_subtotals)
    
    trait :high_volume_store, total_revenue > 10000.0
    trait :northern_store, input.store_region == "north"
  end
end

RSpec.describe "Text Parser: Multiple Array Nesting" do
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

  it "produces identical AST for deep nested array structures" do
    text_dsl = <<~KUMI
      schema do
        input do
          array :departments do
            string :name
            string :location
            array :teams do
              string :team_name
              integer :team_size
              array :members do
                string :member_name
                float :salary
                integer :years_experience
              end
            end
          end
          float :company_budget
        end

        value :all_salaries, input.departments.teams.members.salary
        value :total_salary_cost, fn(:sum, all_salaries)
        trait :over_budget, total_salary_cost > input.company_budget
      end
    KUMI

    compare_asts(DeepNestedArraySchema, text_dsl)
  end

  it "produces identical AST for mixed nested structures with vectorized operations" do
    text_dsl = <<~KUMI
      schema do
        input do
          array :orders do
            string :order_id
            string :customer_name
            array :line_items do
              string :product_name
              float :unit_price
              integer :quantity
              string :category
            end
            float :discount_percentage
          end
          string :store_region, domain: %w[north south east west]
          float :tax_rate
        end

        value :line_subtotals, input.orders.line_items.unit_price * input.orders.line_items.quantity
        value :total_revenue, fn(:sum, line_subtotals)
        trait :high_volume_store, total_revenue > 10000.0
        trait :northern_store, input.store_region == "north"
      end
    KUMI

    compare_asts(MixedNestedStructuresSchema, text_dsl)
  end
end