# frozen_string_literal: true

require "spec_helper"

RSpec.describe "AST Equality: Ruby DSL vs Text Parser" do
  # Helper method to compare ASTs from Ruby DSL and text parser
  def compare_asts(ruby_schema_class, text_dsl)
    # Get AST from existing Ruby DSL
    ruby_ast = ruby_schema_class.__syntax_tree__
    
    # Get AST from text parser  
    text_ast = Kumi::TextParser.parse(text_dsl)
    
    # Compare structure (ignoring location metadata)
    expect(normalize_ast(text_ast)).to eq(normalize_ast(ruby_ast))
  end
  
  # Helper to create Ruby DSL schema for testing
  def create_ruby_schema(&block)
    Class.new do
      extend Kumi::Schema
      schema(&block)
    end
  end
  
  private
  
  def normalize_ast(ast)
    # Remove location info and other parser-specific metadata
    # Keep only the semantic structure
    normalize_node(ast)
  end
  
  def normalize_node(node)
    case node
    when Array
      node.map { |item| normalize_node(item) }
    when Hash
      node.except(:loc, :location).transform_values { |v| normalize_node(v) }
    when Struct
      # For AST nodes (which are Structs), extract all members except location
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

  # Test 1: Basic Input Declaration
  describe "basic input declarations" do
    it "produces identical AST for simple input fields" do
      # Ruby DSL version
      ruby_schema = create_ruby_schema do
        input do
          integer :age, domain: 18..65
          string :status, domain: %w[active inactive]
        end
      end
      
      # Text version
      text_dsl = <<~KUMI
        schema do
          input do
            integer :age, domain: 18..65
            string :status, domain: %w[active inactive]
          end
        end
      KUMI
      
      compare_asts(ruby_schema, text_dsl)
    end

    it "produces identical AST for various input types" do
      ruby_schema = create_ruby_schema do
        input do
          integer :count
          float :price, domain: 0.0..1000.0
          boolean :active
          any :metadata
        end
      end

      text_dsl = <<~KUMI
        schema do
          input do
            integer :count
            float :price, domain: 0.0..1000.0
            boolean :active
            any :metadata
          end
        end
      KUMI

      compare_asts(ruby_schema, text_dsl)
    end
  end

  # Test 2: Simple Values and Traits
  describe "simple values and traits" do
    it "produces identical AST for basic value expressions" do
      ruby_schema = create_ruby_schema do
        input do
          float :price
          integer :quantity
        end
        
        value :subtotal, fn(:multiply, input.price, input.quantity)
      end
      
      text_dsl = <<~KUMI
        schema do
          input do
            float :price
            integer :quantity
          end
          
          value :subtotal, fn(:multiply, input.price, input.quantity)
        end
      KUMI
      
      compare_asts(ruby_schema, text_dsl)
    end

    it "produces identical AST for basic trait expressions" do
      ruby_schema = create_ruby_schema do
        input do
          float :price
        end
        
        trait :expensive, (input.price > 100.0)
      end

      text_dsl = <<~KUMI
        schema do
          input do
            float :price
          end
          
          trait :expensive, (input.price > 100.0)
        end
      KUMI

      compare_asts(ruby_schema, text_dsl)
    end
  end
end