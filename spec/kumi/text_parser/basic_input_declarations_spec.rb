# frozen_string_literal: true

require "spec_helper"

# Test 1: Basic Input Declarations with Sugar Syntax
class BasicInputSchema
  extend Kumi::Schema

  schema do
    input do
      integer :age, domain: 18..65
      string :status, domain: %w[active inactive]
      float :price, domain: 0.0..1000.0
      boolean :verified
    end
  end
end

RSpec.describe "Text Parser: Basic Input Declarations" do
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

  it "produces identical AST for basic input declarations" do
    text_dsl = <<~KUMI
      schema do
        input do
          integer :age, domain: 18..65
          string :status, domain: %w[active inactive]
          float :price, domain: 0.0..1000.0
          boolean :verified
        end
      end
    KUMI

    compare_asts(BasicInputSchema, text_dsl)
  end
end