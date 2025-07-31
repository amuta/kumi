# frozen_string_literal: true

require "spec_helper"

# Test 5: Array Broadcasting and Complex Nested Structures
class ArrayBroadcastingSchema
  extend Kumi::Schema
  
  schema do
    input do
      array :line_items do
        float   :price
        integer :quantity
        string  :category
      end
      float :tax_rate
      string :region, domain: %w[north south east west]
    end

    # Element-wise computation - broadcasts over each item
    value :subtotals, input.line_items.price * input.line_items.quantity
    
    # Element-wise traits - applied to each item
    trait :is_taxable, (input.line_items.category != "digital")
    trait :high_value_items, (input.line_items.price > 50.0)
    
    # Aggregation operations - consume arrays to produce scalars
    value :total_subtotal, fn(:sum, subtotals)
    value :item_count, fn(:size, input.line_items)
    value :max_quantity, fn(:max, input.line_items.quantity)
    
    # Mixed operations
    trait :bulk_order, (input.item_count >= 5)
    trait :high_value_order, (input.total_subtotal > 1000.0)
    trait :northern_region, (input.region == "north")
  end
end

RSpec.describe "Text Parser: Array Broadcasting and Nested Structures" do
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

  it "produces identical AST for array broadcasting and nested structures" do
    text_dsl = <<~KUMI
      schema do
        input do
          array :line_items do
            float   :price
            integer :quantity
            string  :category
          end
          float :tax_rate
          string :region, domain: %w[north south east west]
        end

        value :subtotals, input.line_items.price * input.line_items.quantity
        trait :is_taxable, (input.line_items.category != "digital")
        trait :high_value_items, (input.line_items.price > 50.0)
        value :total_subtotal, fn(:sum, subtotals)
        value :item_count, fn(:size, input.line_items)
        value :max_quantity, fn(:max, input.line_items.quantity)
        trait :bulk_order, (input.item_count >= 5)
        trait :high_value_order, (input.total_subtotal > 1000.0)
        trait :northern_region, (input.region == "north")
      end
    KUMI

    compare_asts(ArrayBroadcastingSchema, text_dsl)
  end
end