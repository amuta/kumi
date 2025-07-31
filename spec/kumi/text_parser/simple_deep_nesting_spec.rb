# frozen_string_literal: true

require "spec_helper"

# Test simple deep nesting to isolate the issue
class SimpleDeepNestedSchema
  extend Kumi::Schema
  
  schema do
    input do
      array :departments do
        string :name
        array :teams do
          string :team_name
          integer :team_size
        end
      end
    end

    value :all_team_names, input.departments.teams.team_name
  end
end

RSpec.describe "Text Parser: Simple Deep Nesting" do
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

  it "produces identical AST for simple deep nesting" do
    text_dsl = <<~KUMI
      schema do
        input do
          array :departments do
            string :name
            array :teams do
              string :team_name
              integer :team_size
            end
          end
        end

        value :all_team_names, input.departments.teams.team_name
      end
    KUMI

    compare_asts(SimpleDeepNestedSchema, text_dsl)
  end
end